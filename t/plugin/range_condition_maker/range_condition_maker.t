use strict;
use warnings;
use utf8;

use FindBin::libs;
use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use Mouse::Util;
use t::Util;

run_on_database {
    Mouse::Util::apply_all_roles(db, 'Aniki::Plugin::RangeConditionMaker');

    db->insert_multi(author => [map {
        +{ name => $_ }
    } qw/MOZNION KARUPA PAPIX MACKEE/]);

    for my $type (qw/lower gt/) {
        my $where  = db->make_range_condition({ $type => { id => 2 } });
        my $result = db->select('author', $where);
        is scalar (map { $_->{id} > 2 } @{ $result->row_datas }), 2;
    }

    for my $type (qw/upper lt/) {
        my $where  = db->make_range_condition({ $type => { id => 4 } });
        my $result = db->select('author', $where);
        is scalar (map { $_->{id} < 4 } @{ $result->row_datas }), 3;
    }
};

done_testing();
