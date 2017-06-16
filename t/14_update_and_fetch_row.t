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

    my $new_row = db->update_and_fetch_row($row, +{ name => 'KARUPA' });
    isa_ok $new_row, 'Aniki::Row';
    is $new_row->name, 'KARUPA';
    is $new_row->message, 'hello Aniki';

    eval {
        db->update_and_fetch_row($rows, +{ name => 'MACKEE' });
    };
    like $@, qr/update_and_fetch_row/m;
};

done_testing();
