use strict;
use warnings;
use utf8;

use Test::More;

package MyProj::DB::Filter {
    use Aniki::Filter::Declare;

    table hoge => sub {
        inflate foo => sub {
            my $value = shift;
            return "hoge_inflate_$value";
        };

        deflate foo => sub {
            my $value = shift;
            return "hoge_deflate_$value";
        };
    };

    inflate bar => sub {
        my $value = shift;
        return "global_inflate_$value";
    };

    deflate bar => sub {
        my $value = shift;
        return "global_deflate_$value";
    };
};

my $filter = MyProj::DB::Filter->instance;

subtest table => sub {
    is $filter->inflate_row(hoge => { foo => 'foo_value' })->{foo}, 'hoge_inflate_foo_value';
    is $filter->deflate_row(hoge => { foo => 'foo_value' })->{foo}, 'hoge_deflate_foo_value';
    is $filter->inflate_row(hoge => { foo => 'foo_value' })->{foo}, 'hoge_inflate_foo_value';
    is $filter->deflate_row(hoge => { foo => 'foo_value' })->{foo}, 'hoge_deflate_foo_value';
    is $filter->inflate_row(fuga => { foo => 'foo_value' })->{foo}, 'foo_value';
    is $filter->deflate_row(fuga => { foo => 'foo_value' })->{foo}, 'foo_value';
    is $filter->inflate_row(fuga => { foo => 'foo_value' })->{foo}, 'foo_value';
    is $filter->deflate_row(fuga => { foo => 'foo_value' })->{foo}, 'foo_value';
};

subtest global => sub {
    is $filter->inflate_row(hoge => { bar => 'bar_value' })->{bar}, 'global_inflate_bar_value';
    is $filter->deflate_row(hoge => { bar => 'bar_value' })->{bar}, 'global_deflate_bar_value';
    is $filter->inflate_row(hoge => { bar => 'bar_value' })->{bar}, 'global_inflate_bar_value';
    is $filter->deflate_row(hoge => { bar => 'bar_value' })->{bar}, 'global_deflate_bar_value';
    is $filter->inflate_row(fuga => { bar => 'bar_value' })->{bar}, 'global_inflate_bar_value';
    is $filter->deflate_row(fuga => { bar => 'bar_value' })->{bar}, 'global_deflate_bar_value';
    is $filter->inflate_row(fuga => { bar => 'bar_value' })->{bar}, 'global_inflate_bar_value';
    is $filter->deflate_row(fuga => { bar => 'bar_value' })->{bar}, 'global_deflate_bar_value';
};

done_testing;
