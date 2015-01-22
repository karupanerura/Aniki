use strict;
use warnings;
use utf8;

use Test::More;
use Aniki::Filter;

subtest 'global deflator only' => sub {
    my $filter = Aniki::Filter->new();
    $filter->add_global_deflator(foo => sub {
        my $value = shift;
        return "global_$value";
    });
    is $filter->deflate_row(hoge => { foo  => 'foo_value' })->{foo},   'global_foo_value';
    is $filter->deflate_row(fuga => { foo  => 'foo_value' })->{foo},   'global_foo_value';
    is $filter->deflate_row(hoge => { foo2 => 'foo2_value' })->{foo2}, 'foo2_value';
    is $filter->deflate_row(fuga => { foo2 => 'foo2_value' })->{foo2}, 'foo2_value';
};

subtest 'table deflator only' => sub {
    my $filter = Aniki::Filter->new();
    $filter->add_table_deflator(hoge => foo => sub {
        my $value = shift;
        return "hoge_$value";
    });
    is $filter->deflate_row(hoge => { foo  => 'foo_value' })->{foo},   'hoge_foo_value';
    is $filter->deflate_row(fuga => { foo  => 'foo_value' })->{foo},   'foo_value';
    is $filter->deflate_row(hoge => { foo2 => 'foo2_value' })->{foo2}, 'foo2_value';
    is $filter->deflate_row(fuga => { foo2 => 'foo2_value' })->{foo2}, 'foo2_value';
};

subtest 'table and global deflator' => sub {
    my $filter = Aniki::Filter->new();
    $filter->add_global_deflator(foo => sub {
        my $value = shift;
        return "global_$value";
    });
    $filter->add_table_deflator(hoge => foo => sub {
        my $value = shift;
        return "hoge_$value";
    });
    is $filter->deflate_row(hoge => { foo  => 'foo_value' })->{foo},   'hoge_foo_value';
    is $filter->deflate_row(fuga => { foo  => 'foo_value' })->{foo},   'global_foo_value';
    is $filter->deflate_row(hoge => { foo2 => 'foo2_value' })->{foo2}, 'foo2_value';
    is $filter->deflate_row(fuga => { foo2 => 'foo2_value' })->{foo2}, 'foo2_value';
};

done_testing();
