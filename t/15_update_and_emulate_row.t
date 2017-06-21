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

    my $row = $rows->first;
    is $row->message, 'hello';

    db->update($row => { message => 'hello Aniki' });
    is $row->message, 'hello';

    my $new_row = db->update_and_emulate_row($row, +{ name => 'KARUPA' });
    isa_ok $new_row, 'Aniki::Row';
    is $new_row->name, 'KARUPA';
    is $new_row->message, 'hello';

    eval {
        db->update_and_emulate_row($rows, +{ name => 'MACKEE' });
    };
    like $@, qr/update_and_emulate_row/m;

    subtest 'inflate deflate' => sub {

        is $row->inflate_message, 'inflate hello';
        is $row->deflate_message, 'hello';

        is $new_row->inflate_message, 'inflate hello';
        is $new_row->deflate_message, 'deflate hello';

        $new_row = db->update_and_emulate_row($new_row, +{ inflate_message => 'hello Aniki', deflate_message => 'hello Aniki' });
        isa_ok $new_row, 'Aniki::Row';
        is $new_row->name, 'KARUPA';
        is $new_row->inflate_message, 'inflate hello Aniki';
        is $new_row->deflate_message, 'deflate hello Aniki';
    };
};

done_testing();
