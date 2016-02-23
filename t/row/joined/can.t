use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

use Aniki::Row::Joined;

run_on_database {
    my $author = db->insert_and_fetch_row(author => { name => 'MOZNION' });
    my $module = db->insert_and_fetch_row(module => { name => 'Perl::Lint', author_id => $author->id });

    my $row = Aniki::Row::Joined->new($author, $module);
    can_ok +$row, qw/author module/;
    is +$row->author->table_name, 'author';
    is +$row->module->table_name, 'module';

    eval { $row->version };
    ok $@, 'should not have version';
};

done_testing();
