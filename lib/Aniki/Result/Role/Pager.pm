package Aniki::Result::Role::Pager;
use 5.014002;

use namespace::autoclean;
use Mouse::Role;
use Mouse::Util::TypeConstraints qw/duck_type/;

has pager => (
    is  => 'rw',
    isa => duck_type(qw/entries_per_page current_page entries_on_this_page/),
);

1;
__END__
