package Aniki::QueryBuilder;
use 5.014002;

use strict;
use warnings;

use SQL::Maker 1.19;
use parent qw/SQL::Maker/;

__PACKAGE__->load_plugin('InsertMulti');
__PACKAGE__->load_plugin('InsertOnDuplicate');

1;
__END__
