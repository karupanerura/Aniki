use strict;
use warnings;
use utf8;

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

    my (@warnings, $line, $file); {
        local $SIG{__WARN__} = sub { push @warnings => @_ };
        db->make_range_condtion({ lt => { id => 2 } }); ($file, $line) = (__FILE__, __LINE__);
    };
    is_deeply \@warnings, [
        '[INCOMPATIBLE CHANGE Aniki@1.02] This method is renamed to make_range_condition. the old method is removed at 1.03.'
        ." at $file line $line.$/"
    ] or diag explain \@warnings;


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
