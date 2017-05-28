package Aniki::Plugin::Count;
use 5.014002;

use namespace::autoclean;
use Mouse::Role;

use Carp qw/croak/;

requires qw/query_builder dbh/;

sub count {
    my ($self, $table, $column, $where, $opt) = @_;
    $where //= {};
    $column //= '*';

    croak '(Aniki::Plugin::Count#count) `where` condition must be a reference.' unless ref $where;

    if (ref $column) {
        croak 'Do not pass HashRef/ArrayRef to second argument. Usage: $db->count($table[, $column[, $where[, $opt]]])';
    }

    my ($sql, @binds) = $self->query_builder->select($table, [\"COUNT($column)"], $where, $opt);
    my ($count) = $self->dbh->selectrow_array($sql, undef, @binds);
    return $count;
}

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Plugin::Count - Count rows in database.

=head1 SYNOPSIS

    package MyDB;
    use Mouse v2.4.5;
    extends qw/Aniki/;
    with qw/Aniki::Plugin::Count/;

    package main;
    my $db = MyDB->new(...);
    $db->count('user'); # => The number of rows in 'user' table.
    $db->count('user', '*', {type => 2}); # => SELECT COUNT(*) FROM user WHERE type=2

=head1 SEE ALSO

L<perl>

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
