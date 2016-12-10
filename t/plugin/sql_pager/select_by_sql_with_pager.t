use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use Mouse::Util;
use Aniki::Plugin::SQLPager;
use t::Util;

run_on_database {
    Mouse::Util::apply_all_roles(db, 'Aniki::Plugin::SQLPager');

    db->insert_multi(author => [map {
        +{ name => $_ }
    } qw/MOZNION KARUPA PAPIX/]);

    my $rows = db->select_by_sql_with_pager('SELECT * FROM author ORDER BY id', [], { rows => 2, page => 1 });
    isa_ok $rows, 'Aniki::Result::Collection';
    ok $rows->meta->does_role('Aniki::Result::Role::Pager');
    is $rows->count, 2;
    is $rows->first->id, 1;

    isa_ok $rows->pager, 'Data::Page::NoTotalEntries';
    is $rows->pager->current_page, 1;
    ok $rows->pager->has_next;

    $rows = db->select_by_sql_with_pager('SELECT * FROM author ORDER BY id', [], { rows => 2, page => 2 });
    isa_ok $rows, 'Aniki::Result::Collection';
    ok $rows->meta->does_role('Aniki::Result::Role::Pager');
    is $rows->count, 1;
    is $rows->first->id, 3;

    isa_ok $rows->pager, 'Data::Page::NoTotalEntries';
    is $rows->pager->current_page, 2;
    ok !$rows->pager->has_next;

    $rows = db->select_by_sql_with_pager('SELECT * FROM author WHERE id > ? ORDER BY id', [2], { rows => 2, page => 2, no_offset => 1 });
    isa_ok $rows, 'Aniki::Result::Collection';
    ok $rows->meta->does_role('Aniki::Result::Role::Pager');
    is $rows->count, 1;
    is $rows->first->id, 3;

    isa_ok $rows->pager, 'Data::Page::NoTotalEntries';
    is $rows->pager->current_page, 2;
    ok !$rows->pager->has_next;
};

done_testing();
