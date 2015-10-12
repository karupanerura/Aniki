package t::DB::Schema;
use strict;
use warnings;

use DBIx::Schema::DSL;
use Aniki::Schema::Relationship::Declare;

database 'SQLite';

create_table 'author' => columns {
    integer 'id', primary_key, auto_increment;
    varchar 'name', unique;
    varchar 'message', default => 'hello';
    relay_by 'module', has_many => 1;
};

create_table 'module' => columns {
    integer 'id', primary_key, auto_increment;
    varchar 'name', unique;
    integer 'author_id';

    add_index 'author_id_idx' => ['author_id'];

    relay_to 'author';
    relay_by 'version', has_many => 1;
};

create_table 'version' => columns {
    integer 'id', primary_key, auto_increment;
    varchar 'name';
    integer 'module_id';

    add_unique_index 'module_name_uniq' => ['module_id', 'name'];

    relay_to 'module';
};

1;
