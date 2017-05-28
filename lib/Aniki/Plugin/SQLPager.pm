package Aniki::Plugin::SQLPager;
use 5.014002;

use namespace::autoclean;
use Mouse::Role;

requires qw/select_by_sql select_named/;
with qw/Aniki::Plugin::PagerInjector/;

sub select_by_sql_with_pager {
    my ($self, $sql, $bind, $opt) = @_;
    $opt //= {};

    my $page = $opt->{page} or Carp::croak("required parameter: page");
    my $rows = $opt->{rows} or Carp::croak("required parameter: rows");

    my $limit  = $rows + 1;
    my $offset = $rows * ($page - 1);
    if ($opt->{no_offset}) {
        $sql .= sprintf ' LIMIT %d', $limit;
    }
    else {
        $sql .= sprintf ' LIMIT %d OFFSET %d', $limit, $offset;
    }

    my $result = $self->select_by_sql($sql, $bind, $opt);
    return $self->inject_pager_to_result($result => $opt);
}

sub select_named_with_pager {
    my ($self, $sql, $bind, $opt) = @_;
    $opt //= {};

    my $page = $opt->{page} or Carp::croak("required parameter: page");
    my $rows = $opt->{rows} or Carp::croak("required parameter: rows");

    my $limit  = $rows + 1;
    my $offset = $rows * ($page - 1);
    if ($opt->{no_offset}) {
        $sql .= sprintf ' LIMIT %d', $limit;
    }
    else {
        $sql .= sprintf ' LIMIT %d OFFSET %d', $limit, $offset;
    }

    my $result = $self->select_named($sql, $bind, $opt);
    return $self->inject_pager_to_result($result => $opt);
}

1;
__END__

=pod

=for stopwords sql

=encoding utf-8

=head1 NAME

Aniki::Plugin::SQLPager - SELECT sql with pager

=head1 SYNOPSIS

    package MyDB;
    use Mouse v2.4.5;
    extends qw/Aniki/;
    with qw/Aniki::Plugin::Pager/;

    package main;
    my $db = MyDB->new(...);
    my $result = $db->select_by_sql_with_pager('SELECT * FROM user WHERE type = ?', [ 2 ], { page => 1, rows => 10 }); # => Aniki::Result::Collection(+Aniki::Result::Role::Pager)
    # ALSO OK: my $result = $db->select_named_with_pager('SELECT * FROM user WHERE type = :type', { type => 2 }, { page => 1, rows => 10 }); # => Aniki::Result::Collection(+Aniki::Result::Role::Pager)
    $result->pager; # => Data::Page::NoTotalEntries

=head1 SEE ALSO

L<perl>

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
