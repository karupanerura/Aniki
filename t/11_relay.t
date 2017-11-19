use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

run_on_database {
    my $moznion_id = db->insert_and_fetch_id(author => { name => 'MOZNION' });
    my @moznion_module_ids = (
        db->insert_and_fetch_id(module => { name => 'Perl::Lint',             author_id => $moznion_id }),
        db->insert_and_fetch_id(module => { name => 'Regexp::Lexer',          author_id => $moznion_id }),
        db->insert_and_fetch_id(module => { name => 'Test::JsonAPI::Autodoc', author_id => $moznion_id }),
    );

    my $karupa_id = db->insert_and_fetch_id(author => { name => 'KARUPA' });
    my @karupa_module_ids = (
        db->insert_and_fetch_id(module => { name => 'TOML::Parser',        author_id => $karupa_id }),
        db->insert_and_fetch_id(module => { name => 'Plack::App::Vhost',   author_id => $karupa_id }),
        db->insert_and_fetch_id(module => { name => 'Test::SharedObject',  author_id => $karupa_id }),
    );

    my $mamimu_id = db->insert_and_fetch_id(author => { name => 'MAMIMU' });

    db->insert_multi(version => [map {
        +{ name => '0.01', module_id => $_ },
    } @moznion_module_ids, @karupa_module_ids]);

    subtest 'shallow' => sub {
        subtest 'prefetch' => sub {
            my $queries = query_count {
                my $rows = db->select(author => {}, { prefetch => [qw/modules/] });
                isa_ok $rows, 'Aniki::Result::Collection';
                is $rows->count, 3;
                ok $_->is_prefetched('modules') for $rows->all;

                my %modules = map { $_->name => [sort map { $_->name } $_->modules] } $rows->all;
                is_deeply \%modules, {
                    MOZNION => [qw/Perl::Lint Regexp::Lexer Test::JsonAPI::Autodoc/],
                    KARUPA  => [qw/Plack::App::Vhost TOML::Parser Test::SharedObject/],
                    MAMIMU  => [],
                };
            };
            is $queries, 2;
        };

        subtest 'lazy' => sub {
            my $queries = query_count {
                my $rows = db->select(author => {});
                isa_ok $rows, 'Aniki::Result::Collection';
                is $rows->count, 3;
                ok !$_->is_prefetched('modules') for $rows->all;

                my %modules = map { $_->name => [sort map { $_->name } $_->modules] } $rows->all;
                is_deeply \%modules, {
                    MOZNION => [qw/Perl::Lint Regexp::Lexer Test::JsonAPI::Autodoc/],
                    KARUPA  => [qw/Plack::App::Vhost TOML::Parser Test::SharedObject/],
                    MAMIMU  => [],
                };
            };
            is $queries, 4;
        };
    };

    subtest 'deep' => sub {
        subtest 'prefetch' => sub {
            my $queries = query_count {
                my $rows = db->select(author => {}, { prefetch => { modules => [qw/versions/] } });
                isa_ok $rows, 'Aniki::Result::Collection';
                is $rows->count, 3;
                for my $row ($rows->all) {
                    ok $row->is_prefetched('modules');
                    ok $_->is_prefetched('versions') for $row->modules;
                }

                my %modules = map {
                    $_->name => +{
                        map {
                            $_->name => [map { $_->name } $_->versions],
                        } $_->modules
                    }
                } $rows->all;
                is_deeply \%modules, {
                    MOZNION => +{
                        'Perl::Lint'             => ['0.01'],
                        'Regexp::Lexer'          => ['0.01'],
                        'Test::JsonAPI::Autodoc' => ['0.01'],
                    },
                    KARUPA  => +{
                        'Plack::App::Vhost'  => ['0.01'],
                        'TOML::Parser'       => ['0.01'],
                        'Test::SharedObject' => ['0.01'],
                    },
                    MAMIMU  => +{
                    },
                };
            };
            is $queries, 3;
        };

        subtest 'lazy' => sub {
            my $queries = query_count {
                my $rows = db->select(author => {});
                isa_ok $rows, 'Aniki::Result::Collection';
                is $rows->count, 3;
                for my $row ($rows->all) {
                    ok !$row->is_prefetched('modules');
                    ok !$_->is_prefetched('versions') for $row->modules;
                }

                my %modules = map {
                    $_->name => +{
                        map {
                            $_->name => [map { $_->name } $_->versions],
                        } $_->modules
                    }
                } $rows->all;
                is_deeply \%modules, {
                    MOZNION => +{
                        'Perl::Lint'             => ['0.01'],
                        'Regexp::Lexer'          => ['0.01'],
                        'Test::JsonAPI::Autodoc' => ['0.01'],
                    },
                    KARUPA  => +{
                        'Plack::App::Vhost'  => ['0.01'],
                        'TOML::Parser'       => ['0.01'],
                        'Test::SharedObject' => ['0.01'],
                    },
                    MAMIMU  => +{
                    },
                };
            };
            is $queries, 10;
        };
    };

    subtest 'inverse' => sub {
        subtest 'prefetch' => sub {
            my $queries = query_count {
                my $rows = db->select(author => {}, { prefetch => { modules => [qw/versions/] } });
                isa_ok $rows, 'Aniki::Result::Collection';
                is $rows->count, 3;
                for my $row ($rows->all) {
                    ok $row->is_prefetched('modules');
                    ok $_->is_prefetched('versions') for $row->modules;
                }

                my %modules = map { $_->versions->[0]->module->name => [$_->author->name, map { $_->name } @{ $_->versions }] } map { $_->modules } $rows->all;
                is_deeply \%modules, {
                    'Perl::Lint'             => ['MOZNION', '0.01'],
                    'Regexp::Lexer'          => ['MOZNION', '0.01'],
                    'Test::JsonAPI::Autodoc' => ['MOZNION', '0.01'],
                    'Plack::App::Vhost'      => ['KARUPA',  '0.01'],
                    'TOML::Parser'           => ['KARUPA',  '0.01'],
                    'Test::SharedObject'     => ['KARUPA',  '0.01'],
                } or diag explain \%modules;
            };
            is $queries, 3;
        };

        subtest 'lazy' => sub {
            my $queries = query_count {
                my $rows = db->select(author => {});
                isa_ok $rows, 'Aniki::Result::Collection';
                is $rows->count, 3;
                for my $row ($rows->all) {
                    ok !$row->is_prefetched('modules');
                    ok !$_->is_prefetched('versions') for $row->modules;
                }

                my %modules = map { $_->versions->[0]->module->name => [$_->author->name, map { $_->name } @{ $_->versions }] } map { $_->modules } $rows->all;
                is_deeply \%modules, {
                    'Perl::Lint'             => ['MOZNION', '0.01'],
                    'Regexp::Lexer'          => ['MOZNION', '0.01'],
                    'Test::JsonAPI::Autodoc' => ['MOZNION', '0.01'],
                    'Plack::App::Vhost'      => ['KARUPA',  '0.01'],
                    'TOML::Parser'           => ['KARUPA',  '0.01'],
                    'Test::SharedObject'     => ['KARUPA',  '0.01'],
                } or diag explain \%modules;
            };
            is $queries, 10;
        };
    };

    subtest 'disabled' => sub {
        no warnings qw/once/;
        local *t::DB::use_implicitly_relationship_traversing = sub { 0 };
        use warnings qw/once/;

        subtest 'prefetch' => sub {
            my $queries = query_count {
                my $rows = db->select(author => {}, { prefetch => { modules => [qw/versions/] } });
                isa_ok $rows, 'Aniki::Result::Collection';
                is $rows->count, 3;
                for my $row ($rows->all) {
                    ok $row->is_prefetched('modules');
                    ok $_->is_prefetched('versions') for $row->modules;
                }

                my %modules = map { $_->versions->[0]->module->name => [$_->author->name, map { $_->name } @{ $_->versions }] } map { $_->modules } $rows->all;
                is_deeply \%modules, {
                    'Perl::Lint'             => ['MOZNION', '0.01'],
                    'Regexp::Lexer'          => ['MOZNION', '0.01'],
                    'Test::JsonAPI::Autodoc' => ['MOZNION', '0.01'],
                    'Plack::App::Vhost'      => ['KARUPA',  '0.01'],
                    'TOML::Parser'           => ['KARUPA',  '0.01'],
                    'Test::SharedObject'     => ['KARUPA',  '0.01'],
                } or diag explain \%modules;
            };
            is $queries, 3;
        };

        subtest 'lazy' => sub {
            my $queries = query_count {
                my $rows = db->select(author => {});  my ($file, $line) = (__FILE__, __LINE__);
                isa_ok $rows, 'Aniki::Result::Collection';
                is $rows->count, 3;
                for my $row ($rows->all) {
                    ok !$row->is_prefetched('modules');
                    eval { $row->modules };
                    like $@, qr/^\Qshould use `prefetch` option for modules at $file line $line. author.modules is not pre-fetched/;
                }
            };
            is $queries, 1;
        };
    };

    db->insert_multi(version => [map {
        +{ name => '0.02', module_id => $_ },
    } @moznion_module_ids, @karupa_module_ids]);

    subtest 'extra where conditions' => sub {
        my $queries = query_count {
            my $rows = db->select(author => {}, { prefetch => { modules => { versions => { '.name' => '0.02' } } } });
            isa_ok $rows, 'Aniki::Result::Collection';
            is $rows->count, 3;
            for my $row ($rows->all) {
                ok $row->is_prefetched('modules');
                ok $_->is_prefetched('versions') for $row->modules;
            }

            my %modules = map {
                $_->name => +{
                    map {
                        $_->name => [map { $_->name } $_->versions],
                    } $_->modules
                }
            } $rows->all;
            is_deeply \%modules, {
                MOZNION => +{
                    'Perl::Lint'             => ['0.02'],
                    'Regexp::Lexer'          => ['0.02'],
                    'Test::JsonAPI::Autodoc' => ['0.02'],
                },
                KARUPA  => +{
                    'Plack::App::Vhost'  => ['0.02'],
                    'TOML::Parser'       => ['0.02'],
                    'Test::SharedObject' => ['0.02'],
                },
                MAMIMU  => +{
                },
            } or diag explain \%modules;
        };
        is $queries, 3;
    };
};

done_testing();
