use strict;
use warnings;
use utf8;

use Test::More;
use Aniki::QueryBuilder::Canonical;
use List::Util qw/reduce/;

my $query_builder = Aniki::QueryBuilder::Canonical->new(driver => 'mysql');

my $expect = <<'__QUERY__';
SELECT *
FROM `foo`
WHERE (`bar` = ?) AND (`baz` = ?)
__QUERY__
chomp $expect;

my $ok = reduce { $a && $b } map {
    my ($stmt) = $query_builder->select(foo => ['*'], { bar => 1, baz => 2 });
    $stmt eq $expect;
} 1..1000;
ok $ok, 'can get the same statement always';

done_testing();
