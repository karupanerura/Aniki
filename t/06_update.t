use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

my $db = t::Util->db;

$db->insert(author => { name => 'MOZNION' });
$db->update(author => { name => 'MOZNION2' }, { name => 'MOZNION' });

my $rows = $db->select(author => {});
isa_ok $rows, 'Aniki::Collection';
is $rows->count, 1;
is $rows->first->name, 'MOZNION2', 'updated';

my $row = $rows->first;
$db->update($row => { name => 'MOZNION' });
is $row->name, 'MOZNION2', 'old value';

my $new_row = $row->refetch;
isnt $new_row, $row;
is $new_row->name, 'MOZNION', 'new value';

done_testing();
