use 5.014002;
package MyProj::DB::Schema {
    use DBIx::Schema::DSL;
    use Aniki::Schema::Relationship::Declare;

    database 'SQLite';

    create_table 'author' => columns {
        integer 'id', primary_key, auto_increment;
        varchar 'name', unique;
        relay_by 'module', has_many => 1;
    };

    create_table 'module' => columns {
        integer 'id', primary_key, auto_increment;
        varchar 'name';
        integer 'author_id';

        add_index 'author_id_idx' => ['author_id'];

        relay_to 'author';
    };
};

1;
