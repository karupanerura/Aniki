use strict;
use warnings;
use utf8;

use Test::More;
use Test::Requires qw(Data::WeightedRoundRobin);

use File::Spec;
use lib File::Spec->catfile('t', 'lib');

use Aniki::Handler::WeightedRoundRobin;
use List::Util qw/reduce/;
use List::MoreUtils qw/apply/;

srand 4649;

my @connect_info = (
    {
        value  => ['dbi:mysql:dbname=test;host=db1.localhost;port='.int(rand 65535), 'foo'.int(rand 65535), 'bar'.int(rand 65535), { PrintError => 0, RaiseError => 1 }],
        weight => 10000000,
    },
    {
        value  => ['dbi:mysql:dbname=test;host=db2.localhost;port='.int(rand 65535), 'foo'.int(rand 65535), 'bar'.int(rand 65535), { PrintError => 0, RaiseError => 1 }],
        weight => 10000000,
    },
    {
        value  => ['dbi:mysql:dbname=test;host=db3.localhost;port='.int(rand 65535), 'foo'.int(rand 65535), 'bar'.int(rand 65535), { PrintError => 0, RaiseError => 1 }],
        weight => 10000000,
    },
);

my $handler = Aniki::Handler::WeightedRoundRobin->new(connect_info => \@connect_info);
isa_ok $handler->handler, 'DBIx::Handler';
ok reduce { $a && $b } map { $handler->connect_info()->[0] eq $handler->connect_info()->[0] } 1..100;

my %seen;
for (1..100) {
    $seen{$handler->connect_info->[0]}++;
    $handler->disconnect();
}
ok eq_set(
    [keys %seen],
    [map { $_->{value}->[0] } @connect_info],
);

ok $handler->is_connect_error(q{DBI connect('dbname=test;host=127.0.0.1;port=34783','foo25622',...) failed: Can't connect to MySQL server on '127.0.0.1' (61)});

if (eval { require DBD::mysql; 1 }) {
    my $called = 0;
    no warnings qw/redefine once/;
    local *DBD::mysql::dr::connect = do {
        use warnings qw/redefine once/;
        my $orig = \&DBD::mysql::dr::connect;
        sub {
            $called++;
            goto $orig;
        };
    };
    use warnings qw/redefine once/;

    subtest 'retry connect' => sub {
        $called = 0;
        no warnings qw/redefine once/;
        local *DBIx::Handler::in_txn = do {
            use warnings qw/redefine once/;
            sub { 0 };
        };
        use warnings qw/redefine once/;

        no warnings qw/redefine once/;
        local *Aniki::Handler::WeightedRoundRobin::is_connect_error = do {
            use warnings qw/redefine once/;
            sub { 1 };
        };
        use warnings qw/redefine once/;

        my @warn;
        local $SIG{__WARN__} = sub { push @warn => @_ };
        my $dbh = eval { $handler->dbh };
        note $@;
        ok $@;
        is $dbh, undef;
        is $called, 3;
        is @warn, 2;
    };

    subtest 'no retry connect when in txn' => sub {
        $called = 0;
        no warnings qw/redefine once/;
        local *DBIx::Handler::in_txn = do {
            use warnings qw/redefine once/;
            sub { 1 };
        };
        use warnings qw/redefine once/;

        no warnings qw/redefine once/;
        local *Aniki::Handler::WeightedRoundRobin::is_connect_error = do {
            use warnings qw/redefine once/;
            sub { 1 };
        };
        use warnings qw/redefine once/;

        my $dbh = eval { $handler->dbh };
        note $@;
        ok $@;
        is $dbh, undef;
        is $called, 1;
    };

    subtest 'no retry connect when not connect error' => sub {
        $called = 0;
        no warnings qw/redefine once/;
        local *DBIx::Handler::in_txn = do {
            use warnings qw/redefine once/;
            sub { 1 };
        };
        use warnings qw/redefine once/;

        no warnings qw/redefine once/;
        local *Aniki::Handler::WeightedRoundRobin::is_connect_error = do {
            use warnings qw/redefine once/;
            sub { 0 };
        };
        use warnings qw/redefine once/;

        my $dbh = eval { $handler->dbh };
        note $@;
        ok $@;
        is $dbh, undef;
        is $called, 1;
    };
}

if ($ENV{AUTHOR_TESTING}) {
    require DBD::mysql;
    require Test::mysqld;

    my $mysqld = Test::mysqld->new(
        my_cnf => {
            'skip-networking' => '', # no TCP socket
        }
    );
    {
        no warnings qw/once/;
        die $Test::mysqld::errstr unless $mysqld;
    }

    my @connect_info = apply { $_->{value}->[0] =~ s/db[1-3]\.localhost/127.0.0.1/ } @connect_info;
    my $handler = Aniki::Handler::WeightedRoundRobin->new(connect_info => [@connect_info, { weight => 1, value => [$mysqld->dsn] }]);

    my $called = 0;
    no warnings qw/redefine once/;
    local *Aniki::Handler::WeightedRoundRobin::dbh = do {
        use warnings qw/redefine once/;
        my $super = Aniki::Handler::WeightedRoundRobin->can('dbh');
        sub {
            $called++;
            goto $super;
        };
    };
    use warnings qw/redefine once/;

    subtest 'success to retry connecting' => sub {
        $called = 0;

        my @warn;
        local $SIG{__WARN__} = sub { push @warn => @_ };
        my $dbh = eval { $handler->dbh };
        ok !$@ or diag $@;
        isa_ok $dbh, 'DBI::db';
        is @warn, 3;
        is $called, 4;
    };
}

done_testing();
