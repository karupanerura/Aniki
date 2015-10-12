use strict;
use warnings;
use utf8;

use Test::More;
use Aniki::QueryBuilder::Canonical;
use List::Util qw/reduce/;

my $query_builder = Aniki::QueryBuilder::Canonical->new(driver => 'mysql');

subtest select => sub {
    my $expect = <<'__QUERY__';
SELECT *
FROM `foo`
WHERE (`bar` = ?) AND (`baz` = ?)
__QUERY__
    chomp $expect;
    my @expect = (1, 2);

    my $ok = reduce { $a && $b } map {
        my ($stmt, @bind) = $query_builder->select(foo => ['*'], { bar => 1, baz => 2 });
        $stmt eq $expect && eq_array(\@bind, \@expect);
    } 1..1000;
    ok $ok, 'can get the same statement always';
};

subtest insert => sub {
    my $expect = <<'__QUERY__';
INSERT INTO `foo`
(`bar`, `baz`)
VALUES (?, ?)
__QUERY__
    chomp $expect;
    my @expect = (1, 2);

    my $ok = reduce { $a && $b } map {
        my ($stmt, @bind) = $query_builder->insert(foo => { bar => 1, baz => 2 });
        $stmt eq $expect && eq_array(\@bind, \@expect);
    } 1..1000;
    ok $ok, 'can get the same statement always';
};

subtest update => sub {
    my $expect = 'UPDATE `foo` SET `bar` = ?, `foo` = ? WHERE (`bar` = ?) AND (`baz` = ?)';
    my @expect = (2, 1, 1, 2);

    my $ok = reduce { $a && $b } map {
        my ($stmt, @bind) = $query_builder->update(foo => { foo => 1, bar => 2 }, { bar => 1, baz => 2 });
        $stmt eq $expect && eq_array(\@bind, \@expect);
    } 1..1000;
    ok $ok, 'can get the same statement always';
};

subtest delete => sub {
    my $expect = 'DELETE FROM `foo` WHERE (`bar` = ?) AND (`baz` = ?)';
    my @expect = (1, 2);

    my $ok = reduce { $a && $b } map {
        my ($stmt, @bind) = $query_builder->delete(foo => { bar => 1, baz => 2 });
        $stmt eq $expect && eq_array(\@bind, \@expect);
    } 1..1000;
    ok $ok, 'can get the same statement always';
};

done_testing();
