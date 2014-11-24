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

1;
