use strict;
use warnings;
use utf8;

use Test::More;

use Aniki::Schema;
use Aniki::Schema::Relationships;
use SQL::Translator::Schema::Constants;

package MyTest::Schema {
    use strict;
    use warnings;

    use DBIx::Schema::DSL;

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
        belongs_to 'author';
    };

    create_table 'review' => columns {
        integer 'id', primary_key, auto_increment;
        integer 'module_id';
        integer 'author_id';
        varchar 'description';

        add_index 'module_id_idx' => ['module_id'];
        add_index 'author_id_idx' => ['author_id'];

        belongs_to 'author';
        belongs_to 'module';
    };
};

my $schema = Aniki::Schema->new(schema_class => 'MyTest::Schema');

subtest 'add' => sub {
    my $relationships = Aniki::Schema::Relationships->new(schema => $schema, table => $schema->get_table('author'));
    $relationships->add(
        src_table_name  => 'author',
        src_columns     => [qw/id/],
        dest_table_name => 'module',
        dest_columns    => [qw/author_id/],
    );
    is_deeply [$relationships->get_relationship_names], [qw/modules/];
    $relationships->add(
        src_table_name  => 'author',
        src_columns     => [qw/id/],
        dest_table_name => 'review',
        dest_columns    => [qw/author_id/],
    );
    is_deeply [sort $relationships->get_relationship_names], [qw/modules reviews/];
};

subtest 'add_by_constraint' => sub {
    my $table = $schema->get_table('module');
    my $relationships = Aniki::Schema::Relationships->new(schema => $schema, table => $table);
    my ($belongs_to_author) = grep { $_->type eq FOREIGN_KEY } $table->get_constraints;
    $relationships->add_by_constraint($belongs_to_author);
    is_deeply [$relationships->get_relationship_names], [qw/author/];
};

done_testing();
