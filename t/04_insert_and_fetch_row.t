use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

my $db = t::Util->db;

my $row = $db->insert_and_fetch_row(author => { name => 'MOZNION' });
ok defined $row, 'row is defined.';
ok $row->is_new, 'new row.';

is_deeply $row->get_columns, {
    id   => $row->id,
    name => 'MOZNION',
}, 'Data is valid.';

done_testing();
