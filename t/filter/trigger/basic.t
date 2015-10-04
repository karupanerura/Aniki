use strict;
use warnings;
use utf8;

use Test::More;
use Aniki::Filter;

subtest 'global trigger only' => sub {
    my $filter = Aniki::Filter->new();
    $filter->add_global_trigger(insert => sub {
        my ($row, $next) = @_;
        $row->{baz}++;
        return $next->($row);
    });
    is $filter->apply_trigger(insert => hoge => { foo  => 'foo_value' })->{baz},  1;
    is $filter->apply_trigger(insert => fuga => { foo  => 'foo_value' })->{baz},  1;
    is $filter->apply_trigger(insert => hoge => { foo2 => 'foo2_value' })->{baz}, 1;
    is $filter->apply_trigger(insert => fuga => { foo2 => 'foo2_value' })->{baz}, 1;
};

subtest 'table trigger only' => sub {
    my $filter = Aniki::Filter->new();
    $filter->add_table_trigger(hoge => insert => sub {
        my ($row, $next) = @_;
        $row->{baz}++;
        return $next->($row);
    });
    is $filter->apply_trigger(insert => hoge => { foo  => 'foo_value' })->{baz},  1;
    is $filter->apply_trigger(insert => fuga => { foo  => 'foo_value' })->{baz},  undef;
    is $filter->apply_trigger(insert => hoge => { foo2 => 'foo2_value' })->{baz}, 1;
    is $filter->apply_trigger(insert => fuga => { foo2 => 'foo2_value' })->{baz}, undef;
};

subtest 'table and global trigger' => sub {
    my $filter = Aniki::Filter->new();
    $filter->add_table_trigger(hoge => insert => sub {
        my ($row, $next) = @_;
        $row->{baz}++;
        return $next->($row);
    });
    $filter->add_global_trigger(insert => sub {
        my ($row, $next) = @_;
        $row->{baz}++;
        return $next->($row);
    });
    is $filter->apply_trigger(insert => hoge => { foo  => 'foo_value' })->{baz},  2;
    is $filter->apply_trigger(insert => fuga => { foo  => 'foo_value' })->{baz},  1;
    is $filter->apply_trigger(insert => hoge => { foo2 => 'foo2_value' })->{baz}, 2;
    is $filter->apply_trigger(insert => fuga => { foo2 => 'foo2_value' })->{baz}, 1;
};

done_testing();
