use strict;
use warnings;
use utf8;

use Test::More;

use Aniki::Schema;
use Aniki::Schema::Relationship;

package MyTest::Schema {
    use strict;
    use warnings;

    use DBIx::Schema::DSL;
    use Aniki::Schema::Relationship::Declare;

    database 'SQLite';

    create_table 'author' => columns {
        integer 'id', primary_key, auto_increment;
        varchar 'name', unique;
    };

    create_table 'module' => columns {
        integer 'id', primary_key, auto_increment;
        varchar 'name';
        integer 'author_id';

        add_index 'author_id_idx' => ['author_id'];
    };
};

my $schema = Aniki::Schema->new(schema_class => 'MyTest::Schema');
sub relationship { Aniki::Schema::Relationship->new(schema => $schema, @_) };

subtest 'has_many' => sub {
    ok !!relationship(
        src_table_name  => 'author',
        src_columns     => [qw/id/],
        dest_table_name => 'module',
        dest_columns    => [qw/author_id/],
    )->has_many, 'author has many modules.';
    ok !relationship(
        src_table_name  => 'module',
        src_columns     => [qw/author_id/],
        dest_table_name => 'author',
        dest_columns    => [qw/id/],
    )->has_many, 'module has author.';
};

subtest 'name' => sub {
    is relationship(
        src_table_name  => 'author',
        src_columns     => [qw/id/],
        dest_table_name => 'module',
        dest_columns    => [qw/author_id/],
    )->name, 'modules';
    is relationship(
        src_table_name  => 'module',
        src_columns     => [qw/author_id/],
        dest_table_name => 'author',
        dest_columns    => [qw/id/],
    )->name, 'author';
};

done_testing();
