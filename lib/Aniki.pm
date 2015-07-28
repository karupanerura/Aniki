use 5.014002;
package Aniki {
    use namespace::sweep;
    use Mouse;
    use Module::Load ();
    use Aniki::Row;
    use Aniki::Collection;
    use Aniki::Schema;
    use Aniki::QueryBuilder;

    our $VERSION = '0.02_08';

    use SQL::Maker::SQLType qw/sql_type/;
    use DBIx::Sunny;
    use DBIx::Handler;
    use Carp qw/croak/;
    use Try::Tiny;
    use Scalar::Util qw/blessed/;
    use String::CamelCase qw/camelize/;
    use SQL::NamedPlaceholder qw/bind_named/;

    has connect_info => (
        is       => 'ro',
        isa      => 'ArrayRef',
        required => 1,
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
                dbi_class        => 'DBIx::Sunny',
                on_connect_do    => $self->on_connect_do,
                on_disconnect_do => $self->on_disconnect_do,
            });
        },
    );

    has fields_case => (
        is      => 'rw',
        default => sub { 'NAME_lc' },
    );

    has suppress_row_objects => (
        is      => 'rw',
        default => sub { 0 },
    );

    sub _database2driver {
        my ($class, $database) = @_;
        state $map = {
            MySQL      => 'mysql',
            PostgreSQL => 'Pg',
            SQLite     => 'SQLite',
            Oracle     => 'Oracle',
            DB2        => 'DB2',
        };
        return $map->{$database};
    }

    sub schema        { croak 'This is abstract method.' }
    sub query_builder { croak 'This is abstract method.' }
    sub filter        { croak 'This is abstract method.' }
    sub row_class     { croak 'This is abstract method.' }
    sub result_class  { croak 'This is abstract method.' }

    # You can override this method on your application.
    sub use_strict_query_builder { 1 }

    sub setup {
        my ($class, %args) = @_;

        if (my $schema_class = $args{schema}) {
            Module::Load::load($schema_class);

            my $schema        = Aniki::Schema->new(schema_class => $schema_class);
            my $driver        = $class->_database2driver($schema->database);
            my $query_builder = Aniki::QueryBuilder->new(driver => $driver, strict => $class->use_strict_query_builder);

            $class->meta->add_method(schema        => sub { $schema        });
            $class->meta->add_method(query_builder => sub { $query_builder });
        }
        if (my $filter_class = $args{filter}) {
            Module::Load::load($filter_class);

            my $filter = $filter_class->instance();
            $class->meta->add_method(filter => sub { $filter });
        }

        {
            my $row_class = 'Aniki::Row';
            if ($args{row}) {
                Module::Load::load($args{row});
                $row_class = $args{row};
            }
            $class->meta->add_method(row_class => sub { $row_class });
        }
        {
            my $result_class = 'Aniki::Collection';
            if ($args{result}) {
                Module::Load::load($args{result});
                $result_class = $args{result};
            }
            $class->meta->add_method(result_class => sub { $result_class });
        }
    }

    sub dbh { shift->handler->dbh }

    sub insert {
        my ($self, $table_name, $row, $opt) = @_;
        $row = $self->filter_on_insert($table_name, $row);

        my $table = $self->schema->get_table($table_name);
        $row = $self->_bind_sql_type_to_args($table, $row) if $table;

        my ($sql, @bind) = $self->query_builder->insert($table_name, $row, $opt);
        my $sth  = $self->execute($sql, @bind);
        my $rows = $sth->rows;
        $sth->finish;
        return $rows;
    }

    sub filter_on_insert {
        my ($self, $table_name, $row) = @_;
        return $self->filter->deflate_row($table_name, $row);
    }

    sub update {
        my $self = shift;
        if (blessed $_[0] && $_[0]->isa('Aniki::Row')) {
            return $self->update($_[0]->table_name, $_[1], $self->_where_row_cond($_[0]->table, $_[0]->row_data), @_);
        }
        else {
            my ($table_name, $row, $where, $opt) = @_;
            $row = $self->filter_on_update($table_name, $row);

            my $table = $self->schema->get_table($table_name);
            if ($table) {
                $row   = $self->_bind_sql_type_to_args($table, $row);
                $where = $self->_bind_sql_type_to_args($table, $where);
            }

            my ($sql, @bind) = $self->query_builder->update($table_name, $row, $where, $opt);
            my $sth  = $self->execute($sql, @bind);
            my $rows = $sth->rows;
            $sth->finish;
            return $rows;
        }
    }

    sub delete :method {
        my $self = shift;
        if (blessed $_[0] && $_[0]->isa('Aniki::Row')) {
            return $self->delete($_[0]->table_name, $self->_where_row_cond($_[0]->table, $_[0]->row_data), @_);
        }
        else {
            my ($table_name, $where, $opt) = @_;

            my $table = $self->schema->get_table($table_name);
            if ($table) {
                $where = $self->_bind_sql_type_to_args($table, $where);
            }

            my ($sql, @bind) = $self->query_builder->delete($table_name, $where, $opt);
            my $sth  = $self->execute($sql, @bind);
            my $rows = $sth->rows;
            $sth->finish;
            return $rows;
        }
    }

    sub filter_on_update {
        my ($self, $table_name, $row) = @_;
        return $self->filter->deflate_row($table_name, $row);
    }

    sub insert_and_fetch_id {
        my $self = shift;
        if ($self->insert(@_)) {
            return unless defined wantarray;
            return $self->dbh->last_insert_id;
        }
        else {
            return undef; ## no critic
        }
    }

    sub insert_and_fetch_row {
        my $self       = shift;
        my $table_name = shift;
        my $row_data   = shift;

        my $table = $self->schema->get_table($table_name) or croak "$table_name is not defined in schema.";
        $self->insert($table_name, $row_data, @_);
        return unless defined wantarray;

        my $row = $self->select($table_name, $self->_where_row_cond($table, $row_data), { limit => 1 })->first;
        $row->is_new(1);
        return $row;
    }

    sub insert_on_duplicate {
        my ($self, $table_name, $insert, $update) = @_;
        $insert = $self->filter_on_insert($table_name, $insert);
        $update = $self->filter_on_update($table_name, $update);

        my $table = $self->schema->get_table($table_name);
        if ($table) {
            $insert = $self->_bind_sql_type_to_args($table, $insert);
            $update = $self->_bind_sql_type_to_args($table, $update);
        }

        my ($sql, @bind) = $self->query_builder->insert_on_duplicate($table_name, $insert, $update);
        my $sth  = $self->execute($sql, @bind);
        my $rows = $sth->rows;
        $sth->finish;
        return $rows;
    }

    sub insert_multi {
        my ($self, $table_name, $values, $opts) = @_;
        $opts = defined $opts ? {%$opts} : {};

        my @values = map { $self->filter_on_insert($table_name, $_) } @$values;
        if (exists $opts->{update}) {
            $opts->{update} = $self->filter_on_update($table_name, $opts->{update});
        }

        my $table = $self->schema->get_table($table_name);
        if ($table) {
            $_ = $self->_bind_sql_type_to_args($table, $_) for @values;
            if (exists $opts->{update}) {
                $opts->{update} = $self->_bind_sql_type_to_args($table, $opts->{update});
            }
        }

        my ($sql, @bind) = $self->query_builder->insert_multi($table_name, \@values, $opts);
        my $sth  = $self->execute($sql, @bind);
        my $rows = $sth->rows;
        $sth->finish;
        return $rows;
    }

    sub _where_row_cond {
        my ($self, $table, $row_data) = @_;
        die "@{[ $table->name ]} doesn't have primary key." unless $table->primary_key;

        # fetch by primary key
        my %where;
        for my $pk ($table->primary_key->fields) {
            $where{$pk->name} = exists $row_data->{$pk->name} ? $row_data->{$pk->name}
                              : $pk->is_auto_increment        ? $self->dbh->last_insert_id
                              : undef
                              ;
        }

        return \%where;
    }

    sub select :method {
        my ($self, $table_name, $where, $opt) = @_;
        $opt //= {};

        local $self->{suppress_row_objects} = 1 if $opt->{suppress_row_objects};

        my @columns = ('*');
        my $table = $self->schema->get_table($table_name);
        if ($table) {
            $where   = $self->_bind_sql_type_to_args($table, $where);
            @columns = map { $_->name } $table->get_fields();
        }

        local $Carp::CarpLevel = $Carp::CarpLevel + 1;
        my ($sql, @bind) = $self->query_builder->select($table_name, \@columns, $where, $opt);
        return $self->select_by_sql($sql, \@bind, {
            table_name => $table_name,
            exists $opt->{relay} ? (
                relay => $opt->{relay},
            ) : (),
        });
    }

    sub attach_relay_data {
        my ($self, $table_name, $relay, $rows) = @_;
        return unless @$rows;

        my $relationships = $self->schema->get_relationships($table_name);
        for my $key (@$relay) {
            my $relationship = $relationships->get_relationship($key);
            unless ($relationship) {
                croak "'$key' is not defined as relationship. (maybe possible typo?)";
            }
            $relationship->fetcher($self)->execute($rows);
        }
    }

    sub select_named {
        my ($self, $sql, $bind, $opt) = @_;
        return $self->select_by_sql(bind_named($sql, $bind), $opt);
    }

    sub select_by_sql {
        my ($self, $sql, $bind, $opt) = @_;
        $opt //= {};

        my $table_name = exists $opt->{table_name}  ? $opt->{table_name} : $self->_guess_table_name($sql);
        my $relay      = exists $opt->{relay}       ? $opt->{relay}      : [];

        my $relay_enabled_fg = @$relay && !$self->suppress_row_objects;
        if ($relay_enabled_fg) {
            my $txn; $txn = $self->txn_scope unless $self->in_txn;

            my $sth = $self->execute($sql, @$bind);
            my $result = $self->_fetch_by_sth($sth, $table_name);
            $self->attach_relay_data($table_name, $relay, $result->rows);

            $txn->rollback if defined $txn; ## for read only
            return $result;
        }
        else {
            my $sth = $self->execute($sql, @$bind);
            return $self->_fetch_by_sth($sth, $table_name);
        }
    }

    sub _fetch_by_sth {
        my ($self, $sth, $table_name) = @_;
        my @rows;

        my %row;
        my @columns = @{ $sth->{$self->fields_case} };
        $sth->bind_columns(\@row{@columns});
        push @rows => {%row} while $sth->fetch;
        $sth->finish;

        return $self->result_class->new(
            table_name => $table_name,
            handler    => $self,
            row_datas  => \@rows,
        );
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
            if (ref $args->{$col}) {
                $bind_args{$col} = $args->{$col};
            }
            elsif (my $field = $table->get_field($col)) {
                $bind_args{$col} = sql_type(\$args->{$col}, $field->sql_data_type);
            }
            else {
                $bind_args{$col} = $args->{$col};
            }
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
        return try {
            Module::Load::load($row_class);
            return $row_class;
        } catch {
            die $_ unless /\A\QCan't locate/imo;
            return $self->row_class;
        };
    }

    sub new_row_from_hashref {
        my ($self, $table_name, $row_data) = @_;
        return $row_data if $self->suppress_row_objects;

        my $row_class = $self->guess_row_class($table_name);
        return $row_class->new(
            table_name => $table_name,
            handler    => $self,
            row_data   => $row_data,
        );
    }

    sub new_collection_from_arrayref {
        my ($self, $table_name, $row_datas) = @_;
        return $row_datas if $self->suppress_row_objects;

        return $self->result_class->new(
            table_name => $table_name,
            handler    => $self,
            row_datas  => $row_datas,
        );
    }

    sub _guess_table_name {
        my ($self, $sql) = @_;
        return $2 if $sql =~ /\sfrom\s+(["`]?)([\w]+)\1\s*/sio;
        return;
    }

    # --------------------------------------------------
    # for transaction
    sub txn_manager  { shift->handler->txn_manager }
    sub txn          { shift->handler->txn(@_)          }
    sub in_txn       { shift->handler->in_txn(@_)       }
    sub txn_scope    { shift->handler->txn_scope(@_)    }
    sub txn_begin    { shift->handler->txn_begin(@_)    }
    sub txn_rollback { shift->handler->txn_rollback(@_) }
    sub txn_commit   { shift->handler->txn_commit(@_)   }

    # --------------------------------------------------
    # error handling
    sub handle_error {
        my ($self, $sql, $bind, $e) = @_;
        require Data::Dumper;

        local $Data::Dumper::Maxdepth = 2;
        $sql =~ s/\n/\n          /gm;
        croak sprintf $self->exception_template, $e, $sql, Data::Dumper::Dumper($bind);
    }

    sub exception_template {
        return <<'__TRACE__';
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@ Aniki 's Exception @@@@@
Reason  : %s
SQL     : %s
BIND    : %s
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
__TRACE__
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

            deflate name => sub {
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
        use Mouse;
        extends qw/Aniki/;

        __PACKAGE__->setup(
            schema => 'MyProj::DB::Schema',
            filter => 'MyProj::DB::Filter',
            row    => 'MyProj::DB::Row',
        );
    };

    package main {
        my $db = MyProj::DB->new(connect_info => ["dbi:SQLite:dbname=:memory:", "", ""]);
        $db->execute($_) for split /;/, MyProj::DB::Schema->output;

        my $author_id = $db->insert_and_fetch_id(author => { name => 'songmu' });

        $db->insert(module => {
            name      => 'DBIx::Schema::DSL',
            author_id => $author_id,
        });
        $db->insert(module => {
            name      => 'Riji',
            author_id => $author_id,
        });

        my $module = $db->select(module => {
            name => 'Riji',
        }, {
            limit => 1,
        })->first;
        say '$module->name:         ', $module->name;         ## Riji
        say '$module->author->name: ', $module->author->name; ## SONGMU

        my $author = $db->select(author => {
            name => 'songmu',
        }, {
            limit => 1,
            relay => [qw/modules/],
        })->first;

        say '$author->name:   ', $author->name;                 ## SONGMU
        say 'modules[]->name: ', $_->name for $author->modules; ## DBIx::Schema::DSL, Riji
    };

    1;

=head1 WARNING

IT'S STILL IN DEVELOPMENT PHASE.
I haven't written document and test script yet.

=head1 DESCRIPTION

Aniki is ORM.
Lite, but powerful.

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut

