use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

my $db = t::Util->db;

my $moznion_id = $db->insert_and_fetch_id(author => { name => 'MOZNION' });
$db->insert(module => { name => 'Perl::Lint',             author_id => $moznion_id });
$db->insert(module => { name => 'Regexp::Lexer',          author_id => $moznion_id });
$db->insert(module => { name => 'Test::JsonAPI::Autodoc', author_id => $moznion_id });

my $karupa_id = $db->insert_and_fetch_id(author => { name => 'KARUPA' });
$db->insert(module => { name => 'TOML::Parser',        author_id => $karupa_id });
$db->insert(module => { name => 'Plack::App::Vhost',   author_id => $karupa_id });
$db->insert(module => { name => 'Test::SharedObject',  author_id => $karupa_id });

subtest 'prefetch' => sub {
    my $queries = query_count {
        my $rows = $db->select(author => {}, { relay => [qw/modules/] });
        isa_ok $rows, 'Aniki::Collection';
        is $rows->count, 2;

        my %modules = map { $_->name => [sort map { $_->name } $_->modules] } $rows->all;
        is_deeply \%modules, {
            MOZNION => [qw/Perl::Lint Regexp::Lexer Test::JsonAPI::Autodoc/],
            KARUPA  => [qw/Plack::App::Vhost TOML::Parser Test::SharedObject/],
        };
    };
    is $queries, 2;
};

subtest 'lazy' => sub {
    my $queries = query_count {
        my $rows = $db->select(author => {});
        isa_ok $rows, 'Aniki::Collection';
        is $rows->count, 2;

        my %modules = map { $_->name => [sort map { $_->name } $_->modules] } $rows->all;
        is_deeply \%modules, {
            MOZNION => [qw/Perl::Lint Regexp::Lexer Test::JsonAPI::Autodoc/],
            KARUPA  => [qw/Plack::App::Vhost TOML::Parser Test::SharedObject/],
        };
    };
    is $queries, 3;
};

done_testing();
