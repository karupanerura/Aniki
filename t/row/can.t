use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

run_on_database {
    my $moznion = db->insert_and_fetch_row(author => { name => 'MOZNION' });
    can_ok $moznion, qw/relay get_column name modules/;
    can_ok 't::DB::Row::Author', qw/relay get_column/;
};

done_testing();
