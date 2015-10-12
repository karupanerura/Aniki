use 5.014002;
package Aniki {
    use namespace::sweep;
    use Mouse v2.4.5;
    use Module::Load ();
    use Aniki::Row;
    use Aniki::Result::Collection;
    use Aniki::Schema;
    use Aniki::QueryBuilder;
    use Aniki::QueryBuilder::Canonical;

    our $VERSION = '0.04_03';

    use SQL::Maker::SQLType qw/sql_type/;
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
        default => 0,
    );

    has suppress_result_objects => (
        is      => 'rw',
        default => 0,
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

    sub schema              { croak 'This is abstract method. (required to call setup method before call it)' }
    sub query_builder       { croak 'This is abstract method. (required to call setup method before call it)' }
    sub filter              { croak 'This is abstract method. (required to call setup method before call it)' }
    sub last_insert_id      { croak 'This is abstract method. (required to call setup method before call it)' }
    sub root_row_class      { croak 'This is abstract method. (required to call setup method before call it)' }
    sub guess_row_class     { croak 'This is abstract method. (required to call setup method before call it)' }
    sub root_result_class   { croak 'This is abstract method. (required to call setup method before call it)' }
    sub guess_result_class  { croak 'This is abstract method. (required to call setup method before call it)' }

    # You can override this method on your application.
    sub use_prepare_cached       { 1 }
    sub use_strict_query_builder { 1 }

    sub setup {
        my ($class, %args) = @_;

        # schema
        if (my $schema_class = $args{schema}) {
            Module::Load::load($schema_class);

            my $schema = Aniki::Schema->new(schema_class => $schema_class);
            $class->meta->add_method(schema => sub { $schema });
        }
        else {
            croak 'schema option is required.';
        }

        # filter
        if (my $filter_class = $args{filter}) {
            Module::Load::load($filter_class);

            my $filter = $filter_class->instance();
            $class->meta->add_method(filter => sub { $filter });
        }
        else {
            my $filter = Aniki::Filter->new;
            $class->meta->add_method(filter => sub { $filter });
        }

        # last_insert_id
        {
            my $driver = lc $class->_database2driver($class->schema->database);
            my $method = $class->can("_fetch_last_insert_id_from_$driver") or Carp::croak "Don't know how to get last insert id for $driver";
            $class->meta->add_method(last_insert_id => $method);
        }

        # query_builder
        {
            my $query_builder_class = $class->use_prepare_cached ? 'Aniki::QueryBuilder::Canonical' : 'Aniki::QueryBuilder';
            if ($args{query_builder}) {
                Module::Load::load($args{query_builder});
                $query_builder_class = $args{query_builder};
            }
            my $driver        = $class->_database2driver($class->schema->database);
            my $query_builder = $query_builder_class->new(driver => $driver, strict => $class->use_strict_query_builder);
            $class->meta->add_method(query_builder => sub { $query_builder });
        }

        # row
        {
            my $root_row_class = 'Aniki::Row';
            my %table_row_class;
            if ($args{row}) {
                Module::Load::load($args{row});
                $root_row_class = $args{row};
                for my $table ($class->schema->get_tables) {
                    my $table_row_class = sprintf '%s::%s', $root_row_class, camelize($table->name);
                    $table_row_class{$table->name} = try {
                        Module::Load::load($table_row_class);
                        return $table_row_class;
                    } catch {
                        die $_ unless /\A\QCan't locate/imo;
                        return $root_row_class;
                    };
                }
            }
            else {
                %table_row_class = map { $_->name => $root_row_class } $class->schema->get_tables;
            }
            $class->meta->add_method(root_row_class => sub { $root_row_class });
            $class->meta->add_method(guess_row_class => sub { $table_row_class{$_[1]} //= $root_row_class });
        }

        # result
        {
            my $root_result_class = 'Aniki::Result::Collection';
            my %table_result_class;
            if ($args{result}) {
                Module::Load::load($args{result});
                $root_result_class = $args{result};
                for my $table ($class->schema->get_tables) {
                    my $table_result_class = sprintf '%s::%s', $root_result_class, camelize($table->name);
                    $table_result_class{$table->name} = try {
                        Module::Load::load($table_result_class);
                        return $table_result_class;
                    } catch {
                        die $_ unless /\A\QCan't locate/imo;
                        return $root_result_class;
                    };
                }
            }
            else {
                %table_result_class = map { $_->name => $root_result_class } $class->schema->get_tables;
            }
            $class->meta->add_method(root_result_class => sub { $root_result_class });
            $class->meta->add_method(guess_result_class => sub { $table_result_class{$_[1]} //= $root_result_class });
        }
    }

    sub dbh { shift->handler->dbh }

    sub insert {
        my ($self, $table_name, $row, $opt) = @_;
        $row = $self->filter_on_insert($table_name, $row) unless $opt->{no_filter};

        my $table = $self->schema->get_table($table_name);
        $row = $self->_bind_sql_type_to_args($table, $row) if $table;

        my ($sql, @bind) = $self->query_builder->insert($table_name, $row, $opt);
        $self->execute($sql, @bind)->finish;
    }

    sub filter_on_insert {
        my ($self, $table_name, $row) = @_;
        $row = $self->filter->apply_trigger(insert => $table_name, $row);
        return $self->filter->deflate_row($table_name, $row);
    }

    sub update {
        my $self = shift;
        if (blessed $_[0] && $_[0]->isa('Aniki::Row')) {
            local $Carp::CarpLevel = $Carp::CarpLevel + 1;
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
            local $Carp::CarpLevel = $Carp::CarpLevel + 1;
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
        $row = $self->filter->apply_trigger(update => $table_name, $row);
        return $self->filter->deflate_row($table_name, $row);
    }

    sub insert_and_fetch_id {
        my $self = shift;
        local $Carp::CarpLevel = $Carp::CarpLevel + 1;

        $self->insert(@_);
        return unless defined wantarray;

        my $table_name = shift;
        return $self->last_insert_id($table_name);
    }

    sub insert_and_fetch_row {
        my $self       = shift;
        my $table_name = shift;
        my $row_data   = shift;

        my $table = $self->schema->get_table($table_name) or croak "$table_name is not defined in schema.";

        local $Carp::CarpLevel = $Carp::CarpLevel + 1;
        $self->insert($table_name, $row_data, @_);
        return unless defined wantarray;

        my $row = $self->select($table_name, $self->_where_row_cond($table, $row_data), { limit => 1, suppress_result_objects => 1 })->[0];
        return $row if $self->suppress_row_objects;

        $row->is_new(1);
        return $row;
    }

    sub insert_and_emulate_row {
        my ($self, $table_name, $row, $opt) = @_;

        my $table = $self->schema->get_table($table_name) or croak "$table_name is not defined in schema.";

        local $Carp::CarpLevel = $Carp::CarpLevel + 1;
        $row = $self->filter_on_insert($table_name, $row) unless $opt->{no_filter};

        $self->insert($table_name, $row, { %$opt, no_filter => 1 });
        return unless defined wantarray;

        my %row_data;
        for my $field ($table->get_fields) {
            if (exists $row->{$field->name}) {
                $row_data{$field->name} = $row->{$field->name};
            }
            elsif (my $default_value = $field->default_value) {
                $row_data{$field->name} = $default_value;
            }
            elsif ($field->is_auto_increment) {
                $row_data{$field->name} = $self->last_insert_id($table_name, $field->name);
            }
            else {
                $row_data{$field->name} = undef;
            }
        }
        return \%row_data if $self->suppress_row_objects;
        return $self->guess_row_class($table_name)->new(
            table_name => $table_name,
            handler    => $self,
            row_data   => \%row_data,
            is_new     => 1,
        );
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
                              : $pk->is_auto_increment        ? $self->last_insert_id($table->name, $pk->name)
                              : undef
                              ;
        }

        return \%where;
    }

    sub select :method {
        my ($self, $table_name, $where, $opt) = @_;
        $opt //= {};

        local $self->{suppress_row_objects}    = 1 if $opt->{suppress_row_objects};
        local $self->{suppress_result_objects} = 1 if $opt->{suppress_result_objects};

        my $table = $self->schema->get_table($table_name);

        my @columns = exists $opt->{columns} ? @{ $opt->{columns} }
                    : defined $table ? map { $_->name } $self->schema->get_fields_by_table($table_name)
                    : ('*');

        $where = $self->_bind_sql_type_to_args($table, $where) if defined $table;

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

        $relay = [$relay] if ref $relay eq 'HASH';

        my $relationships = $self->schema->get_table($table_name)->get_relationships;
        for my $key (@$relay) {
            if (ref $key && ref $key eq 'HASH') {
                my %relay = %$key;
                for my $key (keys %relay) {
                    $self->_attach_relay_data($relationships, $rows, $key, $relay{$key});
                }
            }
            else {
                $self->_attach_relay_data($relationships, $rows, $key, []);
            }
        }
    }

    sub _attach_relay_data {
        my ($self, $relationships, $rows, $key, $relay) = @_;
        my $relationship = $relationships->get($key);
        unless ($relationship) {
            croak "'$key' is not defined as relationship. (maybe possible typo?)";
        }
        $relationship->fetcher($self)->execute($rows, $relay);
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
           $relay      = [$relay] if ref $relay eq 'HASH';

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

        if ($self->suppress_result_objects) {
            return \@rows if $self->suppress_row_objects;

            my $row_class = $self->guess_row_class($table_name);
            return [
                map {
                    $row_class->new(
                        table_name => $table_name,
                        handler    => $self,
                        row_data   => $_,
                    )
                } @rows
            ];
        }

        my $result_class = $self->guess_result_class($table_name);
        return $result_class->new(
            table_name => $table_name,
            handler    => $self,
            row_datas  => \@rows,
        );
    }

    sub execute {
        my ($self, $sql, @bind) = @_;
        my $sth = $self->use_prepare_cached ? $self->dbh->prepare_cached($sql) : $self->dbh->prepare($sql);
        $self->_bind_to_sth($sth, \@bind);
        eval {
            $sth->execute();
        };
        if ($@) {
            $self->handle_error($sql, \@bind, $@);
        }
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

    has _row_class_cache => (
        is      => 'rw',
        default => sub {
            my $self = shift;
            my %cache = map { $_->name => undef } $self->schema->get_tables();
            return \%cache;
        },
    );

    has _result_class_cache => (
        is      => 'rw',
        default => sub {
            my $self = shift;
            my %cache = map { $_->name => undef } $self->schema->get_tables();
            return \%cache;
        },
    );

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
        return $row_datas if $self->suppress_result_objects;

        my $result_class = $self->guess_result_class($table_name);
        return $result_class->new(
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
    # last_insert_id
    sub _fetch_last_insert_id_from_mysql { shift->dbh->{mysql_insertid} };
    sub _fetch_last_insert_id_from_pg {
        my ($self, $table_name, $column) = @_;
        my $dbh = $self->dbh;
        return $dbh->last_insert_id(undef, undef, $table_name, undef) unless defined $column;

        my $sequence = join '_', $table_name, $column, 'seq';
        return $dbh->last_insert_id(undef, undef, undef, undef, { sequence => $sequence });
    }
    sub _fetch_last_insert_id_from_sqlite { shift->dbh->sqlite_last_insert_rowid }
    sub _fetch_last_insert_id_from_oracle { undef } ## XXX: Oracle haven't implement AUTO INCREMENT

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

    __PACKAGE__->meta->make_immutable();
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
        use Mouse v2.4.5;
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

