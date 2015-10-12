package SampleDbic::Schema::Author;
use strict;
use warnings;
use utf8;

use parent qw/DBIx::Class::Core/;

__PACKAGE__->table('author');
__PACKAGE__->add_columns(
    'id' => {
        'is_auto_increment' => 1,
        'is_nullable' => 0,
        'data_type' => 'INTEGER',
        'default_value' => undef,
        'is_foreign_key' => 0,
        'size' => '0',
        'name' => 'id'
    },
    'name' => {
        'default_value' => undef,
        'is_foreign_key' => 0,
        'size' => '255',
        'name' => 'name',
        'is_auto_increment' => 0,
        'is_nullable' => 1,
        'data_type' => 'VARCHAR'
    },
    'message' => {
        'is_auto_increment' => 0,
        'data_type' => 'VARCHAR',
        'is_nullable' => 1,
        'default_value' => 'hello',
        'is_foreign_key' => 0,
        'name' => 'message',
        'size' => '255'
    },
);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many('modules' => 'SampleDbic::Schema::Module', { 'foreign.author_id' => 'self.id' });

__PACKAGE__->inflate_column(name => {
    inflate => sub {
        my $name = shift;
        return uc $name;
    },
    deflate => sub {
        my $name = shift;
        return lc $name;
    },
});

1;
