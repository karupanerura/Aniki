use strict;
use warnings;
use utf8;

use Test::More;

use Aniki::Schema::Relationship;

my @keys       = qw/has_many src_table_name src_columns dest_table_name dest_columns/;
my @test_cases = (

    [ 1, 'author', [qw/id/],             'module', [qw/author_id/] ]       => 'modules',
    [ 1, 'author', [qw/id/],             'fish', [qw/author_id/] ]         => 'fish',

    [ 1, 'author', [qw/foo_module/],     'module', [qw/author_bar/] ]      => 'foo_modules',
    [ 1, 'author', [qw/foo/],            'module', [qw/bar_author/] ]      => 'bar_modules',
    [ 1, 'author', [qw/foo_module/],     'module', [qw/author_bar foo/] ]  => 'foo_modules',
    [ 1, 'author', [qw/foo_module foo/], 'module', [qw/author_bar/] ]      => 'modules',
    [ 1, 'author', [qw/foo_module foo/], 'module', [qw/author_bar bar/] ]  => 'modules',

    [ 1, 'author', [qw/id/],             'cpan_module', [qw/author_id/] ]  => 'cpan_modules',
    [ 1, 'author', [qw/id/],             'cpan-module', [qw/author_id/] ]  => 'cpan-modules',
    [ 1, 'author', [qw/id/],             'cpan module', [qw/author_id/] ]  => 'cpan modules',
    [ 1, 'author', [qw/id/],             'cpan/module', [qw/author_id/] ]  => 'cpan/modules',

    [ 0, 'module', [qw/author_id/],      'author', [qw/id/] ]             => 'author',
    [ 0, 'module', [qw/author_id/],      'fish',   [qw/id/] ]             => 'fish',

    [ 0, 'module', [qw/author_bar/],     'author', [qw/foo_module/]     ] => 'foo_author',
    [ 0, 'module', [qw/bar_author/],     'author', [qw/foo/]            ] => 'bar_author',
    [ 0, 'module', [qw/author_bar foo/], 'author', [qw/foo_module/]     ] => 'foo_author',
    [ 0, 'module', [qw/author_bar/],     'author', [qw/foo_module foo/] ] => 'author',
    [ 0, 'module', [qw/author_bar bar/], 'author', [qw/foo_module foo/] ] => 'author',
);

while (@test_cases) {
    my ( $args, $name ) = splice @test_cases, 0, 2;
    is relationship($args)->name, $name, "relationship name is $name";
}

my $schema = bless {}, 'MyTest::Schema';
sub relationship {
    my $args = shift;
    my %args;
    $args{$keys[$_]} = $args->[$_] for 0 .. $#keys;
    Aniki::Schema::Relationship->new( schema => $schema, %args );
}

done_testing();
