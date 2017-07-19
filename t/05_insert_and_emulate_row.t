use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

run_on_database {
    my $row = db->insert_and_emulate_row(author => { name => 'MOZNION' });
    ok defined $row, 'row is defined.';
    ok $row->is_new, 'new row.';

    is_deeply $row->get_columns, {
        id              => $row->id,
        name            => 'MOZNION',
        message         => 'hello',
        inflate_message => 'hello',
        deflate_message => 'hello',
    }, 'Data is valid.';

    subtest 'inflate deflate' => sub {

        is $row->inflate_message, 'inflate hello';
        is $row->deflate_message, 'hello';

        my $new_row = db->insert_and_emulate_row(author => +{ name => 'KARUPA', inflate_message => 'hello Aniki', deflate_message => 'hello Aniki' });
        isa_ok $new_row, 'Aniki::Row';
        is $new_row->name, 'KARUPA';
        is $new_row->inflate_message, 'inflate hello Aniki';
        is $new_row->deflate_message, 'deflate hello Aniki';
    };
};

done_testing();
