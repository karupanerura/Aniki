use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

my $db = t::Util->db;

subtest 'non empty' => sub {
    my $authors = $db->new_collection_from_arrayref(author => [{ name => 'KARUPA' }, { name => 'PAPIX' }]);
    isa_ok $authors, 'Aniki::Result::Collection';
    is $authors->count, 2;
    isa_ok $authors->first, 't::DB::Row::Author';
    is $authors->first->name, 'KARUPA';
};

subtest 'empty' => sub {
    my $authors = $db->new_collection_from_arrayref(author => []);
    isa_ok $authors, 'Aniki::Result::Collection';
    is $authors->count, 0;
};

done_testing();
