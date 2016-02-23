package t::DB;
use 5.014002;
use Mouse v2.4.5;
extends qw/Aniki/;

use Test::Builder;
use t::DB::Exception;

my %CONFIG = (
    schema   => 't::DB::Schema::%s',
    filter   => 't::DB::Filter',
    row      => 't::DB::Row',
);

sub all_databases { qw/SQLite MySQL PostgreSQL/ }

sub run_on_all_databases {
    my $class = shift;
    $class->run_on_each_databases([$class->all_databases] => @_);
}

sub run_on_each_databases {
    my ($class, $databases, $code) = @_;
    for my $database (@$databases) {
        Test::Builder->new->subtest($database => sub {
            my $subclass = eval { $class->get_or_create_anon_class_by_database($database) };
            if (my $reason = $@) {
                if (t::DB::Exception->caught($reason)) {
                    Test::Builder->new->note($reason->message);
                    Test::Builder->new->plan(skip_all => "Cannot use $database");
                    return;
                }
                die $reason; # rethrow
            }
            $subclass->$code($database);
        });
    }
}

sub get_or_create_anon_class_by_database {
    my ($class, $database) = @_;
    state %class_cache;
    return $class_cache{$database} ||= $class->create_anon_class_by_database($database);
}

sub create_anon_class_by_database {
    my ($class, $database) = @_;
    state @heap;

    my $meta = Mouse::Meta::Class->create_anon_class(superclasses => [$class]);
    push @heap => $meta;

    my $subclass = $meta->name;

    my %config = %CONFIG;
    $config{schema} = sprintf $config{schema}, $database;
    $subclass->setup(%config);
    $subclass->prepare_testing($config{schema});
    return $subclass;
}

sub prepare_testing {
    my ($class, $schema_class) = @_;
    my $ddl = $schema_class->output;
    if ($schema_class->context->db eq 'MySQL') {
        eval {
            require DBD::mysql;
            require Test::mysqld;
        };
        t::DB::Exception->throw(message => $@) if $@;

        Test::Builder->new->note('launch mysqld ...');
        my $mysqld = Test::mysqld->new(
            my_cnf => {
                'skip-networking' => '', # no TCP socket
            }
        );
        t::DB::Exception->throw(message => $Test::mysqld::errstr) unless $mysqld;

        my $dbh = DBI->connect($mysqld->dsn(dbname => 'test'), 'root', '', {
            AutoCommit => 1,
            PrintError => 0,
            RaiseError => 1,
        });
        $dbh->do($_) for grep /\S/, split /;/, $ddl;

        $class->meta->add_around_method_modifier(BUILDARGS => sub {
            my $orig  = shift;
            my $class = shift;
            my %args  = @_ == 1 ? %{+shift} : @_;
            $args{connect_info} = [$mysqld->dsn(dbname => 'test'), 'root', ''];
            return $class->$orig(\%args);
        });
    }
    elsif ($schema_class->context->db eq 'PostgreSQL') {
        eval {
            require DBD::Pg;
            require Test::postgresql;
        };
        t::DB::Exception->throw(message => $@) if $@;

        Test::Builder->new->note('launch postgresql ...');
        my $pgsql = Test::postgresql->new();
        t::DB::Exception->throw(message => $Test::postgresql::errstr) unless $pgsql;

        my $dbh = DBI->connect($pgsql->dsn, '', '', {
            AutoCommit => 1,
            PrintError => 0,
            RaiseError => 1,
        });
        $dbh->do($_) for grep /\S/, split /;/, $ddl;

        $class->meta->add_around_method_modifier(BUILDARGS => sub {
            my $orig  = shift;
            my $class = shift;
            my %args  = @_ == 1 ? %{+shift} : @_;
            $args{connect_info} = [$pgsql->dsn];
            return $class->$orig(\%args);
        });
    }
    elsif ($schema_class->context->db eq 'SQLite') {
        require DBD::SQLite;

        Test::Builder->new->note('prepare sqlite ...');
        $class->meta->add_around_method_modifier(BUILDARGS => sub {
            my $orig  = shift;
            my $class = shift;
            my %args  = @_ == 1 ? %{+shift} : @_;
            $args{connect_info} = ['dbi:SQLite:dbname=:memory:', '', ''];
            return $class->$orig(\%args);
        });
        $class->meta->add_method(BUILD => sub {
            my $self = shift;
            $self->execute($_) for grep /\S/, split /;/, $ddl;
        });
    }
    else {
        my $msg = sprintf 'Unknown database: %s', $schema_class->context->db;
        die $msg;
    }
}

1;
