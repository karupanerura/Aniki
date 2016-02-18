use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

run_on_database {
    db->insert(author => { name => 'MOZNION' });
    db->insert(author => { name => 'MOZNION2' });

    is db->select(author => {})->count, 2;

    db->delete(author => { name => 'MOZNION' });

    my $rows = db->select(author => {});
    is $rows->count, 1;

    my $row = $rows->first;
    is $row->name, 'MOZNION2';

    db->delete($row);

    is db->select(author => {})->count, 0;
};

done_testing();
