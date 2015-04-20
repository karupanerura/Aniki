use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::DB;

my $db = t::DB->new(connect_info => ['dbi:SQLite:dbname=:memory:', '', '']);
isa_ok $db, 'Aniki';

subtest 'no connect info' => sub {
    my $db = eval { t::DB->new() }; my ($file, $line) = (__FILE__, __LINE__);
    ok not defined $db;
    like $@, qr/\A\QAttribute (connect_info) is required at $file line $line./m;
};

done_testing();
