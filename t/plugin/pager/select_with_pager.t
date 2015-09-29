use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use Mouse::Util;
use Aniki::Plugin::Pager;
use t::Util;

my $db = t::Util->db;
Mouse::Util::apply_all_roles($db, 'Aniki::Plugin::Pager');

$db->insert_multi(author => [map {
    +{ name => $_ }
} qw/MOZNION KARUPA PAPIX/]);

my $rows = $db->select_with_pager(author => {}, { rows => 2, page => 1 });
isa_ok $rows, 'Aniki::Result::Collection';
ok $rows->meta->does_role('Aniki::Result::Role::Pager');
is $rows->count, 2;

isa_ok $rows->pager, 'Data::Page::NoTotalEntries';
is $rows->pager->current_page, 1;
ok $rows->pager->has_next;

$rows = $db->select_with_pager(author => {}, { rows => 2, page => 2 });
isa_ok $rows, 'Aniki::Result::Collection';
ok $rows->meta->does_role('Aniki::Result::Role::Pager');
is $rows->count, 1;

isa_ok $rows->pager, 'Data::Page::NoTotalEntries';
is $rows->pager->current_page, 2;
ok !$rows->pager->has_next;

done_testing();
