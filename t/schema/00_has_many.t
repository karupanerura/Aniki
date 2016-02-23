use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;
use t::DB;

t::DB->run_on_each_databases([target_databases()] => sub {
    my $class = shift;

    ok !$class->schema->has_many(author => [qw/id/]),      'primary key';
    ok !$class->schema->has_many(author => [qw/name/]),    'unique key';
    ok +$class->schema->has_many(author => [qw/message/]), 'normal';
});

done_testing();
