use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::DB;

t::DB->run_on_all_databases(sub {
    my $class = shift;

    my $db = $class->new();
    isa_ok $db, 'Aniki';
});

subtest 'no connect info' => sub {
    my $db = eval { t::DB->new() };
    ok not defined $db;
    like $@, qr/\A\QAttribute (connect_info) is required/m;
};

done_testing();
