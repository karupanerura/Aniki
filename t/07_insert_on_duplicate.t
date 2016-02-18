use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

use SQL::QueryMaker qw/sql_raw/;

run_on_each_databases [qw/MySQL/] => sub {
    db->insert_on_duplicate(author => {
        name => 'PAPIX',
        message => 'hoge',
    }, {
        message => sql_raw('VALUES(message)'),
    });
    is db->select(author => {}, {})->count, 1, 'created.';
    is db->select(author => { name => 'PAPIX' }, { limit => 1 })->first->message, 'hoge';

    db->insert_on_duplicate(author => {
        name => 'PAPIX',
        message => 'fuga',
    }, {
        message => sql_raw('VALUES(message)'),
    });
    is db->select(author => {}, {})->count, 1, 'updated.';
    is db->select(author => { name => 'PAPIX' }, { limit => 1 })->first->message, 'fuga';
};

done_testing();
