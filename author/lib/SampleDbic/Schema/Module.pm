package SampleDbic::Schema::Module;
use strict;
use warnings;
use utf8;

use parent qw/DBIx::Class::Core/;

__PACKAGE__->table('module');
__PACKAGE__->add_columns(
    'id' => {
        'is_auto_increment' => 1,
        'data_type' => 'INTEGER',
        'size' => '0',
        'name' => 'id',
        'is_foreign_key' => 0,
        'default_value' => undef,
        'is_nullable' => 0
    },
    'name' => {
        'is_foreign_key' => 0,
        'name' => 'name',
        'is_nullable' => 1,
        'default_value' => undef,
        'data_type' => 'VARCHAR',
        'is_auto_increment' => 0,
        'size' => '255'
    },
    'author_id' => {
        'name' => 'author_id',
        'is_foreign_key' => 0,
        'default_value' => undef,
        'is_nullable' => 1,
        'is_auto_increment' => 0,
        'data_type' => 'INTEGER',
        'size' => '0'
    },
);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to('author' => 'SampleDbic::Schema::Author', { 'foreign.id' => 'self.author_id' });

1;
