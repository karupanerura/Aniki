[![Build Status](https://travis-ci.org/karupanerura/Aniki.svg?branch=master)](https://travis-ci.org/karupanerura/Aniki)
# NAME

Aniki - The ORM as our great brother.

# SYNOPSIS

    use 5.014002;
    package MyProj::DB::Schema {
        use DBIx::Schema::DSL;

        create_table 'module' => columns {
            integer 'id', primary_key, auto_increment;
            varchar 'name';
            integer 'author_id';

            add_index 'author_id_idx' => ['author_id'];

            belongs_to 'author';
        };

        create_table 'author' => columns {
            integer 'id', primary_key, auto_increment;
            varchar 'name', unique;
            has_many 'module';
        };
    };

    package MyProj::DB::Filter {
        use Aniki::Filter::Declare;
        use Scalar::Util qw/blessed/;
        use Time::Moment;

        # define inflate/deflate filters in table context.
        table author => sub {
            inflate name => sub {
                my $name = shift;
                return uc $name;
            };

            deflate name => sub {
                my $name = shift;
                return lc $name;
            };
        };

        inflate qr/_at$/ => sub {
            my $datetime = shift;
            $datetime =~ tr/ /T/;
            $datetime .= 'Z';
            return Time::Moment->from_string($datetime);
        };

        deflate qr/_at$/ => sub {
            my $datetime = shift;
            return $datetime->at_utc->strftime('%F %T') if blessed $datetime and $datetime->isa('Time::Moment');
            return $datetime;
        };
    };

    package MyProj::DB {
        use Mouse v2.4.5;
        extends qw/Aniki/;

        __PACKAGE__->setup(
            schema => 'MyProj::DB::Schema',
            filter => 'MyProj::DB::Filter',
            row    => 'MyProj::DB::Row',
        );
    };

    package main {
        my $db = MyProj::DB->new(connect_info => ["dbi:SQLite:dbname=:memory:", "", ""]);
        $db->execute($_) for split /;/, MyProj::DB::Schema->output;

        my $author_id = $db->insert_and_fetch_id(author => { name => 'songmu' });

        $db->insert(module => {
            name      => 'DBIx::Schema::DSL',
            author_id => $author_id,
        });
        $db->insert(module => {
            name      => 'Riji',
            author_id => $author_id,
        });

        my $module = $db->select(module => {
            name => 'Riji',
        }, {
            limit => 1,
        })->first;
        say '$module->name:         ', $module->name;         ## Riji
        say '$module->author->name: ', $module->author->name; ## SONGMU

        my $author = $db->select(author => {
            name => 'songmu',
        }, {
            limit => 1,
            relay => [qw/modules/],
        })->first;

        say '$author->name:   ', $author->name;                 ## SONGMU
        say 'modules[]->name: ', $_->name for $author->modules; ## DBIx::Schema::DSL, Riji
    };

    1;

# WARNING

IT'S STILL IN DEVELOPMENT PHASE.
I haven't written document and test script yet.

# DESCRIPTION

Aniki is ORM.
Lite, but powerful.

# LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

karupanerura <karupa@cpan.org>
