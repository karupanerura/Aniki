package Aniki::QueryBuilder {
    use strict;
    use warnings;
    use utf8;

    use SQL::Maker 1.19;
    use parent qw/SQL::Maker/;

    __PACKAGE__->load_plugin('InsertMulti');
    __PACKAGE__->load_plugin('InsertOnDuplicate');
}

1;
__END__
