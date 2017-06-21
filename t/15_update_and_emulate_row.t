use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

run_on_database {
    my $row = db->insert_and_fetch_row(author => { name => 'MOZNION' });
    subtest 'assert default (in|de)flate_message' => sub {
        is $row->inflate_message, 'inflate hello', 'inflated: inflate_message';
        is $row->deflate_message, 'hello', 'inflated: deflate_message';
        is $row->get_column('inflate_message'), 'hello', 'raw: inflate_message';
        is $row->get_column('deflate_message'), 'hello', 'raw: deflate_message';
    };

    subtest 'croak' => sub {
        my ($line, $file);
        eval {
            ($line, $file) = (__LINE__, __FILE__); db->update_and_emulate_row(undef, +{ name => 'MACKEE' });
        };
        like $@, qr/^\Q(Aniki#update_and_emulate_row) condition must be a Aniki::Row object. at $file line $line/m, 'croak from update_and_emulate_row';

        eval {
            ($line, $file) = (__LINE__, __FILE__); db->update_and_emulate_row($row, undef);
        };
        like $@, qr/^\Q(Aniki#update) `row` is required for update ("SET" parameter) at $file line $line/m, 'croak from update';
    };

    subtest 'emulate new row' => sub {
        local db->{suppress_row_objects} = 1;
        my $new_row = db->update_and_emulate_row($row, +{ name => 'PAPIX' });
        isa_ok $new_row, 'HASH';
        is $new_row->{$_}, $row->get_column($_), "raw: $_" for grep { $_ ne 'name' } db->schema->get_table('author')->field_names;
        is $new_row->{name}, 'PAPIX', 'raw: name';
    };
    $row = $row->refetch;

    subtest 'emulate new row object' => sub {
        my $new_row = db->update_and_emulate_row($row, +{ name => 'KARUPA' });
        isa_ok $new_row, 'Aniki::Row';
        is_deeply $new_row->get_columns, {
            %{ $row->get_columns },
            name => 'KARUPA',
        }, 'raw: @columuns';
        is $new_row->$_, $row->$_, "inflated: $_" for grep { $_ ne 'name' } db->schema->get_table('author')->field_names;
        is $new_row->name, 'KARUPA', 'inflated: name';
        $row = $new_row;
    };

    subtest 'emulate inflate/deflate' => sub {
        my $new_row = db->update_and_emulate_row($row, +{ inflate_message => 'hello world', deflate_message => 'hello world' });
        is $new_row->inflate_message, 'inflate hello world', 'inflated: inflate_message';
        is $new_row->deflate_message, 'deflate hello world', 'inflated: deflate_message';
        is $new_row->get_column('inflate_message'), 'hello world', 'raw: inflate_message';
        is $new_row->get_column('deflate_message'), 'deflate hello world', 'raw: deflate_message';
    };
};

done_testing();
