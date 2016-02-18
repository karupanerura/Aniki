package t::DB::Schema::Common;
use strict;
use warnings;

use DBIx::Schema::DSL;
use Aniki::Schema::Relationship::Declare;

create_table 'author' => columns {
    integer 'id', primary_key, auto_increment, extra => { auto_increment_type => 'monotonic' };
    varchar 'name';
    varchar 'message', default => 'hello';

    add_unique_index 'name_uniq_in_author' => ['name'];

    relay_by 'module', has_many => 1;
};

create_table 'module' => columns {
    integer 'id', primary_key, auto_increment, extra => { auto_increment_type => 'monotonic' };
    varchar 'name';
    integer 'author_id';

    add_index 'author_id_idx' => ['author_id'];
    add_unique_index 'name_uniq_in_module' => ['name'];

    relay_to 'author';
    relay_by 'version', has_many => 1;
};

create_table 'version' => columns {
    integer 'id', primary_key, auto_increment, extra => { auto_increment_type => 'monotonic' };
    varchar 'name';
    integer 'module_id';

    add_unique_index 'module_name_uniq_in_version' => ['module_id', 'name'];

    relay_to 'module';
};

1;
__END__
