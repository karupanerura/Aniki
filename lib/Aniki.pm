use 5.014002;
package Aniki 0.01 {
    use namespace::sweep;
    use Moo;
    use Aniki::Row;
    use Aniki::Types;

    use Module::Load ();
    use Aniki::QueryBuilder;
    use SQL::Maker::SQLType;
    use DBIx::Sunny;
    use DBIx::Handler;
    use Carp qw/croak/;
    use Try::Tiny;
    use Teng;
    use Module::Load ();
    use String::CamelCase qw/camelize/;

    our $SUPPRESS_ROW_OBJECTS = 0;

    has connect_info => (
        is       => 'ro',
        isa      => Aniki::Types->type('ConnectInfo'),
        required => 1,
    );

    has dbi_class => (
        is      => 'ro',
        default => sub { 'DBIx::Sunny' },
    );

    has row_class => (
        is      => 'ro',
        default => sub { 'Aniki::Row' },
    );

    has on_connect_do => (
        is => 'ro',
    );

    has on_disconnect_do => (
        is => 'ro',
    );

    has handler => (
        is      => 'ro',
        default => sub {
            my $self = shift;
            my ($dsn, $user, $pass, $attr) = @{ $self->connect_info };
            return DBIx::Handler->new($dsn, $user, $pass, $attr, {
                dbi_class        => $self->dbi_class,
                on_connect_do    => $self->on_connect_do,
                on_disconnect_do => $self->on_disconnect_do,
            });
        },
    );

    has fields_case => (
        is      => 'rw',
        default => sub { 'NAME_lc' },
    );

    sub _database2driver {
        my ($class, $database) = @_;

        return +{
            MySQL      => 'mysql',
            PostgreSQL => 'Pg',
            SQLite     => 'SQLite',
            Oracle     => 'Oracle',
            DB2        => 'DB2',
        }->{$database};
    }

    sub setup {
        my ($class, %args) = @_;

        if (my $schema_class = $args{schema}) {
            Module::Load::load($schema_class);

            my $schema        = $schema_class->context->schema;
            my $driver        = $class->_database2driver($schema->database);
            my $query_builder = Aniki::QueryBuilder->new(driver => $driver);

            $class->meta->add_method(schema        => sub { $schema        });
            $class->meta->add_method(query_builder => sub { $query_builder });
        }
        if (my $filter_class = $args{filter}) {
            Module::Load::load($filter_class);
            $class->meta->add_method(filter => sub { $filter_class });
        }
    }

    sub dbh { shift->handler->dbh }

    sub insert {
        my ($self, $table_name, $row, $opt) = @_;
        my $table = $self->schema->get_table($table_name);
        $row = $self->_bind_sql_type_to_args($table, $row) if $table;
        $row = $self->filter->deflate_row($table_name, $row);

        my ($sql, @bind) = $self->query_builder->insert($table_name, $row, $opt);
        return $self->execute($sql, @bind)->rows;
    }

    sub update {
        my ($self, $table_name, $row, $where, $opt) = @_;
        my $table = $self->schema->get_table($table_name);
        if ($table) {
            $row   = $self->_bind_sql_type_to_args($table, $row);
            $where = $self->_bind_sql_type_to_args($table, $where);
        }
        $row = $self->filter->deflate_row($table_name, $row);

        my ($sql, @bind) = $self->query_builder->update($table_name, $row, $where, $opt);
        return $self->execute($sql, @bind)->rows;
    }

    sub insert_and_fetch_id {
        my $self = shift;
        $self->insert(@_);
        return $self->dbh->last_insert_id;
    }

    sub insert_and_fetch_row {
        my $self       = shift;
        my $table_name = shift;
        my $row        = shift;

        my $table = $self->schema->get_table($table_name) or croak "$table_name is not defined in schema.";
        $self->insert($table_name, $row, @_);

        # fetch by primary key
        my %where;
        for my $pk ($table->primary_key->fields) {
            $where{$pk->name} = $pk->is_auto_increment ? $self->dbh->last_insert_id : $row->{$pk->name};
        }
        my ($row) = $self->select($table_name, \%where, { limit => 1 });
        return $row;
    }

    sub select :method {
        my ($self, $table_name, $where, $opt) = @_;
        $opt //= {};

        my @columns = ('*');
        my $table = $self->schema->get_table($table_name);
        if ($table) {
            $where   = $self->_bind_sql_type_to_args($table, $where);
            @columns = map { $_->name } $table->get_fields();
        }

        my ($sql, @bind) = $self->query_builder->select($table_name, \@columns, $where, $opt);
        return $self->select_by_sql($sql, \@bind, $table_name);
    }

    sub select_by_sql {
        my ($self, $sql, $bind, $table_name) = @_;
        $table_name //= $self->_guess_table_name($sql);

        my $sth = $self->execute($sql, @$bind);

        # fetch
        my $columns = $sth->{$self->aniki->fields_case};
        my $rows    = $sth->rows;
        my $results = $sth->fetchall_arrayref({
            FetchHashKeyName => $self->aniki->fields_case,
            Slice            => {},
        });

        $sth->finish;

        return (@$results) if $SUPPRESS_ROW_OBJECTS;

        my $row_class = $self->guess_row_class($table_name);
        return map {
            $row_class->new(
                table_name => $table_name,
                schema     => $self->schema,
                filter     => $self->filter,
                row_data   => $_,
            )
        } @$results;
    }

    sub execute {
        my ($self, $sql, @bind) = @_;
        my $sth = $self->dbh->prepare($sql);
        $self->_bind_to_sth($sth, \@bind);
        try {
            $sth->execute();
        }
        catch {
            $self->handle_error($sql, \@bind, $_);
        };
        return $sth;
    }

    sub _bind_sql_type_to_args {
        my ($self, $table, $args) = @_;

        my %bind_args;
        for my $col (keys %{$args}) {
            # if $args->{$col} is a ref, it is scalar ref or already
            # sql type bined parameter. so ignored.
            $bind_args{$col} = ref $args->{$col} ? $args->{$col} : sql_type(\$args->{$col}, $table->get_field($col)->sql_data_type);
        }

        return \%bind_args;
    }

    sub _bind_to_sth {
        my ($self, $sth, $bind) = @_;
        for my $i (keys @$bind) {
            my $v = $bind->[$i];
            if (blessed $v && $v->isa('SQL::Maker::SQLType')) {
                $sth->bind_param($i + 1, ${$v->value_ref}, $v->type);
            } else {
                $sth->bind_param($i + 1, $v);
            }
        }
    }

    sub guess_row_class {
        my ($self, $table_name) = @_;
        my $row_class = sprintf '%s::%s', $self->row_class, camelize($table_name);
        my $success   = try { Module::Load::load($row_class); 1 };
        return $success ? $row_class : $self->row_class;
    }

    sub _guess_table_name {
        my ($self, $sql) = @_;
        return $1 if $sql =~ /\sfrom\s+["`]?([\w]+)["`]?\s*/sio;
        return;
    }

    # --------------------------------------------------
    # for transaction
    sub txn          { shift->handler->txn(@_)          }
    sub in_txn       { shift->handler->in_txn(@_)       }
    sub txn_scope    { shift->handler->txn_scope(@_)    }
    sub txn_begin    { shift->handler->txn_begin(@_)    }
    sub txn_rollback { shift->handler->txn_rollback(@_) }
    sub txn_commit   { shift->handler->txn_commit(@_)   }

        our $EXCEPTION_TEMPLATE   = <<'__TRACE__';
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@ Aniki 's Exception @@@@@
Reason  : %s
SQL     : %s
BIND    : %s
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
__TRACE__

    sub handle_error {
        my ($self, $sql, $bind, $e) = @_;
        require Data::Dumper;

        local $Data::Dumper::Maxdepth = 2;
        $sql =~ s/\n/\n          /gm;
        croak sprintf $EXCEPTION_TEMPLATE, $e, $sql, Data::Dumper::Dumper($bind);
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Aniki - The ORM as our great brother.

=head1 SYNOPSIS

    use 5.014002;
    package MyProj::DB::Schema {
        use DBIx::Schema::DSL;

        create_table 'module' => columns {
            integer 'id', primary_key, auto_increment;
            varchar 'name';
            integer 'author_id';

            add_index 'author_id_idx' => ['author_id'];

            belongs_to 'author';
        };

        create_table 'author' => columns {
            integer 'id', primary_key, auto_increment;
            varchar 'name', unique;
            has_many 'module';
        };
    };

    package MyProj::DB::Filter {
        use Aniki::Filter::Declare;
        use Scalar::Util qw/blessed/;
        use Time::Moment;

        # define inflate/deflate filters in table context.
        table author => sub {
            inflate name => sub {
                my $name = shift;
                return uc $name;
            };

            deflate author => name => sub {
                my $name = shift;
                return lc $name;
            };
        };

        inflate qr/_at$/ => sub {
            my $datetime = shift;
            $datetime =~ tr/ /T/;
            $datetime .= 'Z';
            return Time::Moment->from_string($datetime);
        };

        deflate qr/_at$/ => sub {
            my $datetime = shift;
            return $datetime->at_utc->strftime('%F %T') if blessed $datetime and $datetime->isa('Time::Moment');
            return $datetime;
        };
    };

    package MyProj::DB {
        use Moo;
        extends qw/Aniki/;

        __PACKAGE__->setup(
            schema => 'MyProj::DB::Schema',
            filter => 'MyProj::DB::Filter',
        );
    };

    package main {
        my $db = MyProj::DB->new(...);
        $db->schema->add_table(name => $_) for $db->schema->get_tables;
        my $author_id = $db->insert_and_fetch_id(author => { name => 'songmu' });

        $db->insert(module => {
            name      => 'DBIx::Schema::DSL',
            author_id => $author_id,
        });
        $db->insert(module => {
            name      => 'Riji',
            author_id => $author_id,
        });

        my ($module) = $db->select(module => {
            name => 'Riji',
        }, {
            limit => 1,
        });
        $module->name;         ## Riji
        $module->author->name; ## SONGMU

        my ($author) = $db->select(author => {
            name => 'songmu',
        }, {
            limit => 1,
            relay => [qw/module/],
        });
        $author->name;                 ## SONGMU
        $_->name for $author->modules; ## DBIx::Schema::DSL, Riji
    };

    1;

=head1 DESCRIPTION

Aniki is ...

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut

