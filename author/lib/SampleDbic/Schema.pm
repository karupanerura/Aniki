package SampleDbic::Schema;
use strict;
use warnings;
use utf8;

use parent qw/DBIx::Class::Schema/;
use SampleDbic::Schema::Author;
use SampleDbic::Schema::Module;

__PACKAGE__->register_class('Author', 'SampleDbic::Schema::Author');
__PACKAGE__->register_class('Module', 'SampleDbic::Schema::Module');

1;
