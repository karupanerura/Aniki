package t::DB;
use Mouse;
extends qw/Aniki/;

__PACKAGE__->setup(
    schema => 't::DB::Schema',
    filter => 't::DB::Filter',
    row    => 't::DB::Row',
);

1;
