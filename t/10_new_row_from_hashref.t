use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

my $db = t::Util->db;

my $karupa = $db->new_row_from_hashref(author => { name => 'KARUPA' });
isa_ok $karupa, 't::DB::Row::Author';
is $karupa->name, 'KARUPA';

done_testing();
