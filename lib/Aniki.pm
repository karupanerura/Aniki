package Aniki;
use 5.014002;

use namespace::sweep;
use Mouse v2.4.5;

use Module::Load ();
use Aniki::Filter;
use Aniki::Handler;
use Aniki::Row;
use Aniki::Result::Collection;
use Aniki::Schema;
use Aniki::QueryBuilder;
use Aniki::QueryBuilder::Canonical;

our $VERSION = '1.00';

use SQL::Maker::SQLType qw/sql_type/;
use Class::Inspector;
use Carp qw/croak confess/;
use Try::Tiny;
use Scalar::Util qw/blessed/;
use String::CamelCase qw/camelize/;
use SQL::NamedPlaceholder qw/bind_named/;

sub _noop {}

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my %args  = (@_ == 1 && ref $_[0] eq 'HASH') ? %{$_[0]} : @_;

    if (not exists $args{handler}) {
        my $connect_info     = delete $args{connect_info} or confess 'Attribute (connect_info) is required';
        my $on_connect_do    = delete $args{on_connect_do};
        my $on_disconnect_do = delete $args{on_disconnect_do};
        my $trace_query      = delete $args{trace_query} || 0;
        my $trace_ignore_if  = delete $args{trace_ignore_if} || \&_noop;
        $args{handler} = $class->handler_class->new(
            connect_info     => $connect_info,
            on_connect_do    => $on_connect_do,
            on_disconnect_do => $on_disconnect_do,
            trace_query      => $trace_query,
            trace_ignore_if  => $trace_ignore_if,
        );
    }

    return $class->$orig(\%args);
};

has handler => (
    is       => 'ro',
    required => 1,
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
sub handler_class       { 'Aniki::Handler' }

# You can override this method on your application.
sub use_prepare_cached       { 1 }
sub use_strict_query_builder { 1 }

sub setup {
    my ($class, %args) = @_;

    # schema
    if (my $schema_class = $args{schema}) {
        Module::Load::load($schema_class) unless Class::Inspector->loaded($schema_class);

        my $schema = Aniki::Schema->new(schema_class => $schema_class);
        $class->meta->add_method(schema => sub { $schema });
    }
    else {
        croak 'schema option is required.';
    }

    # filter
    if (my $filter_class = $args{filter}) {
        Module::Load::load($filter_class) unless Class::Inspector->loaded($filter_class);

        my $filter = $filter_class->instance();
        $class->meta->add_method(filter => sub { $filter });
    }
    else {
        my $filter = Aniki::Filter->new;
        $class->meta->add_method(filter => sub { $filter });
    }

    # handler
    if (my $handler_class = $args{handler}) {
        Module::Load::load($handler_class) unless Class::Inspector->loaded($handler_class);
        $class->meta->add_method(handler_class => sub { $handler_class });
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
            Module::Load::load($args{query_builder}) unless Class::Inspector->loaded($args{query_builder});
            $query_builder_class = $args{query_builder};
        }
        my $driver        = $class->_database2driver($class->schema->database);
        my $query_builder = $query_builder_class->new(driver => $driver, strict => $class->use_strict_query_builder);
        $class->meta->add_method(query_builder => sub { $query_builder });
    }

    # row
    {
        my $root_row_class = 'Aniki::Row';
        my $guess_row_class = sub { $root_row_class };
        if ($args{row}) {
            Module::Load::load($args{row}) unless Class::Inspector->loaded($args{row});
            $root_row_class = $args{row};

            my %table_row_class;
            $guess_row_class = sub {
                my $table_name = $_[1];
                return $table_row_class{$table_name} //= try {
                    my $table_row_class = sprintf '%s::%s', $root_row_class, camelize($table_name);
                    Module::Load::load($table_row_class);
                    return $table_row_class;
                } catch {
                    die $_ unless /\A\QCan't locate/imo;
                    return $root_row_class;
                };
            };
        }
        $class->meta->add_method(root_row_class => sub { $root_row_class });
        $class->meta->add_method(guess_row_class => $guess_row_class);
    }

    # result
    {
        my $root_result_class = 'Aniki::Result::Collection';
        my $guess_result_class = sub { $root_result_class };
        if ($args{result}) {
            Module::Load::load($args{result}) unless Class::Inspector->loaded($args{result});
            $root_result_class = $args{result};

            my %table_result_class;
            $guess_result_class = sub {
                my $table_name = $_[1];
                return $table_result_class{$table_name} //= try {
                    my $table_result_class = sprintf '%s::%s', $root_result_class, camelize($table_name);
                    Module::Load::load($table_result_class);
                    return $table_result_class;
                } catch {
                    die $_ unless /\A\QCan't locate/imo;
                    return $root_result_class;
                };
            };
        }

        $class->meta->add_method(root_result_class => sub { $root_result_class });
        $class->meta->add_method(guess_result_class => $guess_result_class);
    }
}

sub preload_all_row_classes {
    my $class = shift;
    for my $table ($class->schema->get_tables) {
        $class->guess_row_class($table->name);
    }
}

sub preload_all_result_classes {
    my $class = shift;
    for my $table ($class->schema->get_tables) {
        $class->guess_result_class($table->name);
    }
}

sub dbh {
    my $self = shift;
    # (for mysql)
    # XXX: `DBIx::Handler#dbh` send a ping to mysql.
    #      But, It removes `$dbh->{mysql_insertid}`.
    return $self->{_context} if exists $self->{_context};
    return $self->handler->dbh;
}

sub insert {
    my ($self, $table_name, $row, $opt) = @_;
    $row = $self->filter_on_insert($table_name, $row) unless $opt->{no_filter};

    my $table = $self->schema->get_table($table_name);
    $row = $self->_bind_sql_type_to_args($table, $row) if $table;

    my ($sql, @bind) = $self->query_builder->insert($table_name, $row, $opt);
    $self->execute($sql, @bind);
    return;
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
        return $self->update($_[0]->table_name, $_[1], $self->_where_row_cond($_[0]->table, $_[0]->row_data));
    }
    else {
        my ($table_name, $row, $where) = @_;
        croak '(Aniki#update) `where` condition must be a reference.' unless ref $where;

        $row = $self->filter_on_update($table_name, $row);

        my $table = $self->schema->get_table($table_name);
        if ($table) {
            $row   = $self->_bind_sql_type_to_args($table, $row);
            $where = $self->_bind_sql_type_to_args($table, $where);
        }

        my ($sql, @bind) = $self->query_builder->update($table_name, $row, $where);
        return $self->execute($sql, @bind)->rows;
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
        croak '(Aniki#delete) `where` condition must be a reference.' unless ref $where;

        my $table = $self->schema->get_table($table_name);
        if ($table) {
            $where = $self->_bind_sql_type_to_args($table, $where);
        }

        my ($sql, @bind) = $self->query_builder->delete($table_name, $where, $opt);
        return $self->execute($sql, @bind)->rows;
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

    local $self->{_context} = $self->dbh;
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
    local $self->{_context} = $self->dbh;

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
    local $self->{_context} = $self->dbh;

    $row = $self->filter_on_insert($table_name, $row) unless $opt->{no_filter};

    $self->insert($table_name, $row, { %$opt, no_filter => 1 });
    return unless defined wantarray;

    my %row_data;
    for my $field ($table->get_fields) {
        if (exists $row->{$field->name}) {
            $row_data{$field->name} = $row->{$field->name};
        }
        elsif (defined(my $default_value = $field->default_value)) {
            $row_data{$field->name} = ref $default_value eq 'SCALAR' ? undef : $default_value;
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
    if ($self->schema->database ne 'MySQL') {
        Carp::croak 'Cannot use insert_on_duplicate (unsupported without MySQL)';
    }

    $insert = $self->filter_on_insert($table_name, $insert);
    $update = $self->filter_on_update($table_name, $update);

    my $table = $self->schema->get_table($table_name);
    if ($table) {
        $insert = $self->_bind_sql_type_to_args($table, $insert);
        $update = $self->_bind_sql_type_to_args($table, $update);
    }

    my ($sql, @bind) = $self->query_builder->insert_on_duplicate($table_name, $insert, $update);
    $self->execute($sql, @bind);
    return;
}

sub insert_multi {
    my ($self, $table_name, $values, $opts) = @_;
    return unless @$values;

    $opts = defined $opts ? {%$opts} : {};

    my @values = map { $self->filter_on_insert($table_name, $_) } @$values;
    if (exists $opts->{update}) {
        if ($self->schema->database ne 'MySQL') {
            Carp::croak 'Cannot use insert_multi with update option (unsupported without MySQL)';
        }
        $opts->{update} = $self->filter_on_update($table_name, $opts->{update});
    }

    my $table = $self->schema->get_table($table_name);
    if ($table) {
        $_ = $self->_bind_sql_type_to_args($table, $_) for @values;
        if (exists $opts->{update}) {
            $opts->{update} = $self->_bind_sql_type_to_args($table, $opts->{update});
        }
    }

    if ($self->schema->database eq 'MySQL') {
        my ($sql, @bind) = $self->query_builder->insert_multi($table_name, \@values, $opts);
        $self->execute($sql, @bind);
    }
    else {
        $self->txn(sub {
            local $self->{_context} = shift;
            $self->insert($table_name, $_, $opts) for @values;
        });
    }
    return;
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

my $WILDCARD_COLUMNS = ['*'];

sub select :method {
    my ($self, $table_name, $where, $opt) = @_;
    $where //= {};
    $opt //= {};

    croak '(Aniki#select) `where` condition must be a reference.' unless ref $where;

    my $table = $self->schema->get_table($table_name);

    my $columns = exists $opt->{columns} ? $opt->{columns}
                : defined $table ? $table->field_names
                : $WILDCARD_COLUMNS;

    $where = $self->_bind_sql_type_to_args($table, $where) if defined $table;

    local $Carp::CarpLevel = $Carp::CarpLevel + 1;
    my ($sql, @bind) = $self->query_builder->select($table_name, $columns, $where, $opt);
    return $self->select_by_sql($sql, \@bind, {
        %$opt,
        table_name => $table_name,
        columns    => $columns,
    });
}

sub fetch_and_attach_relay_data {
    my ($self, $table_name, $prefetch, $rows) = @_;
    return unless @$rows;

    $prefetch = [$prefetch] if ref $prefetch eq 'HASH';

    my $relationships = $self->schema->get_table($table_name)->get_relationships;
    for my $key (@$prefetch) {
        if (ref $key && ref $key eq 'HASH') {
            my %prefetch = %$key;
            for my $key (keys %prefetch) {
                $self->_fetch_and_attach_relay_data($relationships, $rows, $key, $prefetch{$key});
            }
        }
        else {
            $self->_fetch_and_attach_relay_data($relationships, $rows, $key, []);
        }
    }
}

sub _fetch_and_attach_relay_data {
    my ($self, $relationships, $rows, $key, $prefetch) = @_;
    my $relationship = $relationships->get($key);
    unless ($relationship) {
        croak "'$key' is not defined as relationship. (maybe possible typo?)";
    }
    $relationship->fetcher->execute($self, $rows, $prefetch);
}

sub select_named {
    my ($self, $sql, $bind, $opt) = @_;
    return $self->select_by_sql(bind_named($sql, $bind), $opt);
}

sub select_by_sql {
    my ($self, $sql, $bind, $opt) = @_;
    $opt //= {};

    local $self->{suppress_row_objects}    = 1 if $opt->{suppress_row_objects};
    local $self->{suppress_result_objects} = 1 if $opt->{suppress_result_objects};

    my $table_name = exists $opt->{table_name}  ? $opt->{table_name} : $self->_guess_table_name($sql);
    my $columns    = exists $opt->{columns}     ? $opt->{columns}    : undef;
    my $prefetch   = exists $opt->{prefetch}    ? $opt->{prefetch}      : [];
       $prefetch   = [$prefetch] if ref $prefetch eq 'HASH';

    my $prefetch_enabled_fg = @$prefetch && !$self->suppress_row_objects && defined wantarray;
    if ($prefetch_enabled_fg) {
        my $txn; $txn = $self->txn_scope(caller => [caller]) unless $self->in_txn;

        my $sth = $self->execute($sql, @$bind);
        my $result = $self->_fetch_by_sth($sth, $table_name, $columns);
        $self->fetch_and_attach_relay_data($table_name, $prefetch, $result->rows);

        $txn->rollback if defined $txn; ## for read only
        return $result;
    }

    my $sth = $self->execute($sql, @$bind);

    # When the return value is never used, should not create object
    # case example: use `FOR UPDATE` query for global locking
    unless (defined wantarray) {
        $sth->finish();
        return;
    }

    return $self->_fetch_by_sth($sth, $table_name, $columns);
}

sub _fetch_by_sth {
    my ($self, $sth, $table_name, $columns) = @_;
    $columns //= $sth->{NAME};
    $columns   = $sth->{NAME} if $columns == $WILDCARD_COLUMNS;

    my @rows;

    my %row;
    $sth->bind_columns(\@row{@$columns});
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
        table_name           => $table_name,
        handler              => $self,
        row_datas            => \@rows,
        suppress_row_objects => $self->suppress_row_objects,
    );
}

sub execute {
    my ($self, $sql, @bind) = @_;
    $sql = $self->handler->trace_query_set_comment($sql);

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
        table_name           => $table_name,
        handler              => $self,
        row_datas            => $row_datas,
        suppress_row_objects => $self->suppress_row_objects,
    );
}

sub _guess_table_name {
    my ($self, $sql) = @_;
    return $2 if $sql =~ /\sfrom\s+(["`]?)([\w]+)\1\s*/sio;
    return;
}

# --------------------------------------------------
# last_insert_id
sub _fetch_last_insert_id_from_mysql { shift->dbh->{mysql_insertid} }
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

sub DEMOLISH {
    my $self = shift;
    $self->handler->disconnect() if $self->handler;
}

__PACKAGE__->meta->make_immutable();
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
            limit    => 1,
            prefetch => [qw/modules/],
        })->first;

        say '$author->name:   ', $author->name;                 ## SONGMU
        say 'modules[]->name: ', $_->name for $author->modules; ## DBIx::Schema::DSL, Riji
    };

    1;

=head1 DESCRIPTION

Aniki is ORM.
Lite, but powerful.

=head2 FEATURES

=over 4

=item Small & Simple

You can read codes easily.

=item Object mapping

Inflates rows to L<Aniki::Result::Collection> object.
And inflates row to L<Aniki::Row> object.

You can change result class, also we can change row class.
Aniki dispatches result/row class by table. (e.g. C<foo> table to C<MyDB::Row::Foo>)

=item Raw SQL support

Supports to execute raw C<SELECT> SQL and fetch rows of result.
Of course, Aniki can inflate to result/row also.

=item Query builder

Aniki includes query builder powered by L<SQL::Maker>.
L<SQL::Maker> is fast and secure SQL builder.

=item Fork safe & Transaction support

Aniki includes L<DBI> handler powered by L<DBIx::Handler>.

=item Error handling

Easy to handle execution errors by C<handle_error> method.
You can override it.

=item Extendable

You can extend Aniki by L<Mouse::Role>.
Aniki provides some default plugins as L<Mouse::Role>.

=back

=head2 RELATIONSHIP

Aniki supports relationship.
Extracts relationship from schema class.

Example:

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
        };
    };

A C<author> has many C<modules>.
So you can access C<author> row object to C<modules>.

    my $author = $db->select(author => { name => 'songmu' })->first;
    say 'modules[]->name: ', $_->name for $author->modules; ## DBIx::Schema::DSL, Riji

Also C<module> has a C<author>.
So you can access C<module> row object to C<author> also.

    my $module = $db->select(module => { name => 'Riji' })->first;
    say "Riji's author is ", $module->author->name; ## SONGMU

And you can pre-fetch related rows.

    my @modules = $db->select(module => {}, { prefetch => [qw/author/] });
    say $_->name, "'s author is ", $_->author->name for @modules;

=head1 SETUP

Install Aniki from CPAN:

    cpanm Aniki

And run C<install-aniki> command.

    install-aniki --lib=./lib MyApp::DB

C<install-aniki> creates skeleton modules.

=head1 METHODS

=head2 CLASS METHODS

=head3 C<setup(%args)>

Initialize and customize Aniki class.
C<schema> is required. Others are optional.

=head4 Arguments

=over 4

=item schema : ClassName

=item handler : ClassName

=item filter : ClassName

=item row : ClassName

=item result : ClassName

=item query_builder : ClassName

=back

=head3 C<use_prepare_cached>

If this method returns true value, Aniki uses C<preare_cached>.
This method returns true value default.
So you don't need to use C<preare_cached>, override it and return false value.

=head3 C<use_strict_query_builder>

If this method returns true value, Aniki enables L<SQL::Maker>'s strict mode.
This method returns true value default.
So you need to disable L<SQL::Maker>'s strict mode, override it and return false value.

SEE ALSO: L<The JSON SQL Injection Vulnerability|http://blog.kazuhooku.com/2014/07/the-json-sql-injection-vulnerability.html>

=head3 C<preload_all_row_classes>

Preload all row classes.

=head3 C<preload_all_result_classes>

Preload all result classes.

=head3 C<guess_result_class($table_name) : ClassName>

Guesses result class by table name.

=head3 C<guess_row_class($table_name) : ClassName>

Guesses row class by table name.

=head3 C<new(%args) : Aniki>

Create instance of Aniki.

=head4 Arguments

=over 4

=item C<handler : Aniki::Handler>

Instance of Aniki::Hanlder.
If this argument is given, not required to give C<connect_info> for arguments.

=item C<connect_info : ArrayRef>

Auguments for L<DBI>'s connect method.

=item on_connect_do : CodeRef|ArrayRef[Str]|Str

=item on_disconnect_do : CodeRef|ArrayRef[Str]|Str

Execute SQL or CodeRef when connected/disconnected.

=item trace_query : Bool

Enables to inject a caller information as SQL comment.
SEE ALSO: L<DBIx::Handler>

=item trace_ignore_if : CodeRef

Ignore to inject the SQL comment when trace_ignore_if's return value is true.
SEE ALSO: L<DBIx::Handler>

=item C<suppress_row_objects : Bool>

If this option is true, no create row objects.
Aniki's methods returns hash reference instead of row object.

=item C<suppress_result_objects : Bool>

If this option is true, no create result objects.
Aniki's methods returns array reference instead of result object.

=back

=head2 INSTANCE METHODS

=head3 C<select($table_name, \%where, \%opt)>

Execute C<SELECT> query by generated SQL, and returns result object.

    my $result = $db->select(foo => { id => 1 }, { limit => 1 });
    # stmt: SELECT FROM foo WHERE id = ? LIMIT 1
    # bind: [1]

=head4 Options

There are the options of C<SELECT> query.
See also L<SQL::Maker|https://metacpan.org/pod/SQL::Maker#opt>.

And you can use there options:

=over 4

=item C<suppress_row_objects : Bool>

If this option is true, no create row objects.
This methods returns hash reference instead of row object.

=item C<suppress_result_objects : Bool>

If this option is true, no create result objects.
This method returns array reference instead of result object.

=item C<columns : ArrayRef[Str]>

List for retrieving columns from database.

=item C<prefetch : ArrayRef|HashRef>

Pre-fetch specified related rows.
See also L</"RELATIONSHIP"> section.

=back

=head3 C<select_named($sql, \%bind, \%opt)>

=head3 C<select_by_sql($sql, \@bind, \%opt)>

Execute C<SELECT> query by specified SQL, and returns result object.

    my $result = $db->select_by_sql('SELECT FROM foo WHERE id = ? LIMIT 1', [1]);
    # stmt: SELECT FROM foo WHERE id = ? LIMIT 1
    # bind: [1]

=head4 Options

You can use there options:

=over 4

=item C<table_name: Str>

This is table name using row/result class guessing.

=item C<columns: ArrayRef[Str]>

List for retrieving columns from database.

=item C<prefetch: ArrayRef|HashRef>

Pre-fetch specified related rows.
See also L</"RELATIONSHIP"> section.

=back

=head3 C<insert($table_name, \%values, \%opt)>

Execute C<INSERT INTO> query.

    $db->insert(foo => { bar => 1 });
    # stmt: INSERT INTO foo (bar) VALUES (?)
    # bind: [1]


=head3 C<insert_and_fetch_id($table_name, \%values, \%opt)>

Execute C<INSERT INTO> query, and returns C<last_insert_id>.

    my $id = $db->insert_and_fetch_id(foo => { bar => 1 });
    # stmt: INSERT INTO foo (bar) VALUES (?)
    # bind: [1]

=head3 C<insert_and_fetch_row($table_name, \%values, \%opt)>

Execute C<INSERT INTO> query, and C<SELECT> it, and returns row object.

    my $row = $db->insert_and_fetch_row(foo => { bar => 1 });
    # stmt: INSERT INTO foo (bar) VALUES (?)
    # bind: [1]

=head3 C<insert_and_emulate_row($table_name, \%values, \%opt)>

Execute C<INSERT INTO> query, and returns row object created by C<$row> and schema definition.

    my $row = $db->insert_and_fetch_row(foo => { bar => 1 });
    # stmt: INSERT INTO foo (bar) VALUES (?)
    # bind: [1]

This method is faster than C<insert_and_fetch_row>.

=head4 WARNING

If you use SQL C<TRIGGER> or dynamic default value, this method don't return the correct value, maybe.
In this case, you should use C<insert_and_fetch_row> instead of this method.

=head3 C<insert_on_duplicate($table_name, \%insert, \%update)>

Execute C<INSERT ... ON DUPLICATE KEY UPDATE> query for MySQL.

    my $row = $db->insert_on_duplicate(foo => { bar => 1 }, { bar => \'VALUE(bar) + 1' });
    # stmt: INSERT INTO foo (bar) VALUES (?) ON DUPLICATE KEY UPDATE bar = VALUE(bar) + 1
    # bind: [1]

SEE ALSO: L<INSERT ... ON DUPLICATE KEY UPDATE Syntax|https://dev.mysql.com/doc/refman/5.6/en/insert-on-duplicate.html>

=head3 C<insert_multi($table_name, \@values, \%opts)>

Execute C<INSERT INTO ... (...) VALUES (...), (...), ...> query for MySQL.
Insert multiple rows at once.

    my $row = $db->insert_multi(foo => [{ bar => 1 }, { bar => 2 }, { bar => 3 }]);
    # stmt: INSERT INTO foo (bar) VALUES (?),(?),(?)
    # bind: [1, 2, 3]

SEE ALSO: L<INSERT Syntax|https://dev.mysql.com/doc/refman/5.6/en/insert.html>

=head3 C<update($table_name, \%set, \%where)>

Execute C<UPDATE> query, and returns changed rows count.

    my $count = $db->update(foo => { bar => 2 }, { id => 1 });
    # stmt: UPDATE foo SET bar = ? WHERE id = ?
    # bind: [2, 1]

=head3 C<update($row, \%set)>

Execute C<UPDATE> query, and returns changed rows count.

    my $row = $db->select(foo => { id => 1 }, { limit => 1 })->first;
    my $count = $db->update($row => { bar => 2 });
    # stmt: UPDATE foo SET bar = ? WHERE id = ?
    # bind: [2, 1]

=head3 C<delete($table_name, \%where)>

Execute C<DELETE> query, and returns changed rows count.

    my $count = $db->delete(foo => { id => 1 });
    # stmt: DELETE FROM foo WHERE id = ?
    # bind: [1]

=head3 C<delete($row)>

Execute C<DELETE> query, and returns changed rows count.

    my $row = $db->select(foo => { id => 1 }, { limit => 1 })->first;
    my $count = $db->delete($row);
    # stmt: DELETE foo WHERE id = ?
    # bind: [1]

=head2 ACCESSORS

=over 4

=item C<schema : Aniki::Schema>

=item C<filter : Aniki::Filter>

=item C<query_builder : Aniki::QueryBuilder>

=item C<root_row_class : Aniki::Row>

=item C<root_result_class : Aniki::Result>

=item C<connect_info : ArrayRef>

=item C<on_connect_do : CodeRef|ArrayRef[Str]|Str>

=item C<on_disconnect_do : CodeRef|ArrayRef[Str]|Str>

=item C<suppress_row_objects : Bool>

=item C<suppress_result_objects : Bool>

=item C<dbh : DBI::db>

=item C<handler : Aniki::Handler>

=item C<txn_manager : DBIx::TransactionManager>

=back

=head1 CONTRIBUTE

I need to support documentation and reviewing my english.
This module is developed on L<Github|http://github.com/karupanerura/Aniki>.

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut

