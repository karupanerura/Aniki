use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

my $db = t::Util->db;

my $ret = $db->insert(author => { name => 'MOZNION' });
ok $ret, 'INSERT is successful.';
is $db->select(author => {}, { limit => 1 })->count, 1, 'created.';

done_testing();
