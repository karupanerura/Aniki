use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

use SQL::QueryMaker qw/sql_raw/;

run_on_database {
    is query_count {
        db->insert_multi(author => []);
    }, 0, 'notiong to do if empty values';

    db->insert_multi(author => [
        { name => 'MOZNION',  message => 'hoge' },
        { name => 'PAPIX',    message => 'fuga' },
    ]);
    is db->select(author => {}, {})->count, 2, 'created.';
    is db->select(author => { name => 'PAPIX' }, { limit => 1 })->first->message, 'fuga';

    if (db->query_builder->driver eq 'mysql') {
        db->insert_multi(author => [
            { name => 'PAPIX',  message => 'hoge' },
            { name => 'KARUPA', message => 'fuga' },
        ], {
            update => {
                message => sql_raw('VALUES(message)'),
            }
        });
        is db->select(author => {}, {})->count, 3, 'created.';
        is db->select(author => { name => 'PAPIX' }, { limit => 1 })->first->message, 'hoge';
    };
};

done_testing();
