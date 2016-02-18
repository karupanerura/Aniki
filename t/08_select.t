use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

run_on_database {
    db->insert(author => { name => 'MOZNION' });

    my $rows = db->select(author => {});
    isa_ok $rows, 'Aniki::Result::Collection';
    is $rows->count, 1;
    isa_ok $rows->first, 'Aniki::Row';

    $rows = db->select(author => {
        name => 'OBAKE'
    });
    isa_ok $rows, 'Aniki::Result::Collection';
    is $rows->count, 0;

    $rows = db->select(author => {}, { suppress_row_objects => 1 });
    isa_ok $rows, 'Aniki::Result::Collection';
    is $rows->count, 1;
    isa_ok $rows->first, 'HASH';

    $rows = db->select(author => {}, { suppress_result_objects => 1 });
    isa_ok $rows, 'ARRAY';
    is @$rows, 1;
    isa_ok $rows->[0], 'Aniki::Row';

    $rows = db->select(author => {}, { suppress_result_objects => 1, suppress_row_objects => 1 });
    isa_ok $rows, 'ARRAY';
    is @$rows, 1;
    isa_ok $rows->[0], 'HASH';
};

done_testing();
