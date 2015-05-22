use 5.014002;

package Aniki::Plugin::Count {
    use namespace::sweep;
    use Mouse::Role;

    requires qw/query_builder dbh/;

    sub count {
        my ($self, $table, $column, $where, $opt) = @_;
        $column ||= '*';

        if (ref $column) {
            Carp::croak('Do not pass HashRef/ArrayRef to second argument. Usage: $db->count($table[, $column[, $where[, $opt]]])');
        }

        my ($sql, @binds) = $self->query_builder->select($table, [\"COUNT($column)"], $where, $opt);
        return $self->dbh->select_one($sql, @binds);
    }
}

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Plugin::Count - Count rows in database.

=head1 SYNOPSIS

    package MyDB;
    use Mouse;
    extends qw/Aniki/;
    with qw/Aniki::Plugin::Count/;

    package main;
    my $db = MyDB->new(...);
    $db->count('user'); # => The number of rows in 'user' table.
    $db->count('user', '*', {type => 2}); # => SELECT COUNT(*) FROM user WHERE type=2

=head1 DESCRIPTION

TODO

=head1 SEE ALSO

L<perl>

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
