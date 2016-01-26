use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use Mouse::Util;
use Aniki::Plugin::PagerInjector;
use t::Util;

my $db = t::Util->db;
Mouse::Util::apply_all_roles($db, 'Aniki::Plugin::PagerInjector');

$db->insert_multi(author => [map {
    +{ name => $_ }
} qw/MOZNION KARUPA PAPIX/]);

my $rows = $db->select(author => {}, { limit => 3, offset => 0 });
isa_ok $rows, 'Aniki::Result::Collection';
ok !$rows->meta->does_role('Aniki::Result::Role::Pager');
is $rows->count, 3;

$rows = $db->inject_pager_to_result($rows => { page => 1, rows => 2 });
isa_ok $rows, 'Aniki::Result::Collection';
ok $rows->meta->does_role('Aniki::Result::Role::Pager');
is $rows->count, 2;
isa_ok $rows->pager, 'Data::Page::NoTotalEntries';
is $rows->pager->current_page, 1;
ok $rows->pager->has_next;

$rows = $db->select(author => {}, { limit => 3, offset => 2 });
isa_ok $rows, 'Aniki::Result::Collection';
ok !$rows->meta->does_role('Aniki::Result::Role::Pager');
is $rows->count, 1;

$rows = $db->inject_pager_to_result($rows => { page => 2, rows => 2 });
isa_ok $rows, 'Aniki::Result::Collection';
ok $rows->meta->does_role('Aniki::Result::Role::Pager');
is $rows->count, 1;
isa_ok $rows->pager, 'Data::Page::NoTotalEntries';
is $rows->pager->current_page, 2;
ok !$rows->pager->has_next;

done_testing();
