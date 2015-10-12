package SampleDbic::Schema::Author;
use strict;
use warnings;
use utf8;

use parent qw/DBIx::Class::Core/;

__PACKAGE__->table('author');
__PACKAGE__->add_columns(
    'id' => {
        'is_foreign_key' => 0,
        'name' => 'id',
        'is_nullable' => 0,
        'default_value' => undef,
        'data_type' => 'INTEGER',
        'is_auto_increment' => 1,
        'size' => '0'
    },
    'name' => {
        'size' => '255',
        'is_auto_increment' => 0,
        'data_type' => 'VARCHAR',
        'default_value' => undef,
        'is_nullable' => 1,
        'is_foreign_key' => 0,
        'name' => 'name'
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
