use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');

use Aniki::Handler::WeightedRoundRobin;
use List::Util qw/reduce/;

if (!eval { require Data::WeightedRoundRobin; 1 }) {
    plan skip_all => 'Data::WeightedRoundRobin is required for WeightedRoundRobin handler';
}

srand 4649;

my @connect_info = (
    {
        value  => ['dbi:mysql:dbname=test;host=db1.localhost;port='.int(rand 65535), 'foo'.int(rand 65535), 'bar'.int(rand 65535), { PrintError => 0, RaiseError => 1 }],
        weight => 10,
    },
    {
        value  => ['dbi:mysql:dbname=test;host=db2.localhost;port='.int(rand 65535), 'foo'.int(rand 65535), 'bar'.int(rand 65535), { PrintError => 0, RaiseError => 1 }],
        weight => 10,
    },
    {
        value  => ['dbi:mysql:dbname=test;host=db3.localhost;port='.int(rand 65535), 'foo'.int(rand 65535), 'bar'.int(rand 65535), { PrintError => 0, RaiseError => 1 }],
        weight => 10,
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

done_testing();
