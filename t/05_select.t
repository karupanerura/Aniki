use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

my $db = t::Util->db;

$db->insert(author => { name => 'MOZNION' });

my $rows = $db->select(author => {});
isa_ok $rows, 'Aniki::Result::Collection';
is $rows->count, 1;

$rows = $db->select(author => {
    name => 'OBAKE'
});
isa_ok $rows, 'Aniki::Result::Collection';
is $rows->count, 0;

done_testing();
