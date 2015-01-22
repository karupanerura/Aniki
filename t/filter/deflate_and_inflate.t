use strict;
use warnings;
use utf8;

use Test::More;
use Aniki::Filter;

my @PATTERN = (
    [hoge => { foo  => 'foo_value'  }],
    [fuga => { foo  => 'foo_value'  }],
    [hoge => { foo2 => 'foo2_value' }],
    [fuga => { foo2 => 'foo2_value' }],
);

subtest 'global' => sub {
    my $filter = Aniki::Filter->new();
    $filter->add_global_inflator(foo => sub {
        my $value = shift;
        return "global_inflate_$value";
    });
    $filter->add_global_deflator(foo => sub {
        my $value = shift;
        return "global_deflate_$value";
    });

    for my $pattern (@PATTERN) {
        my ($table, $row) = @$pattern;
        my ($column) = keys %$row;
        is $filter->deflate_row($table, $row)->{$column}, $column eq 'foo' ? 'global_deflate_foo_value' : $row->{$column};
        is $filter->inflate_row($table, $row)->{$column}, $column eq 'foo' ? 'global_inflate_foo_value' : $row->{$column};
    }
};

subtest 'table' => sub {
    my $filter = Aniki::Filter->new();
    $filter->add_table_inflator(hoge => foo => sub {
        my $value = shift;
        return "hoge_inflate_$value";
    });
    $filter->add_table_deflator(hoge => foo => sub {
        my $value = shift;
        return "hoge_deflate_$value";
    });
    for my $pattern (@PATTERN) {
        my ($table, $row) = @$pattern;
        my ($column) = keys %$row;
        is $filter->deflate_row($table, $row)->{$column}, $table eq 'hoge' && $column eq 'foo' ? 'hoge_deflate_foo_value' : $row->{$column};
        is $filter->inflate_row($table, $row)->{$column}, $table eq 'hoge' && $column eq 'foo' ? 'hoge_inflate_foo_value' : $row->{$column};
    }
};

done_testing();
