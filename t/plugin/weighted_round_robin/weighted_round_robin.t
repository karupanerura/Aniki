use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use Mouse::Util;
use t::Util;

if (!eval { require Data::WeightedRoundRobin; 1 }) {
    plan skip_all => 'Data::WeightedRoundRobin is required for WeightedRoundRobin plugin';
}

my $db = t::Util->db;
Mouse::Util::apply_all_roles($db, 'Aniki::Plugin::WeightedRoundRobin');
is $db->handler_class, 'Aniki::Handler::WeightedRoundRobin';

done_testing();
