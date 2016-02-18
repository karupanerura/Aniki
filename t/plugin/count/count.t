use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use Mouse::Util;
use Aniki::Plugin::Count;
use t::Util;

run_on_database {
    Mouse::Util::apply_all_roles(db, 'Aniki::Plugin::Count');

    db->insert_multi(author => [map {
        +{ name => $_ }
    } qw/MOZNION KARUPA PAPIX/]);

    my $count = db->count('author');
    is $count, 3;

    $count = db->count('author', '*', { name => 'MOZNION' });
    is $count, 1;
};

done_testing();
