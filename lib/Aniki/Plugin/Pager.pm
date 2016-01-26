package Aniki::Plugin::Pager;
use 5.014002;

use namespace::sweep;
use Mouse::Role;

requires qw/select/;
with qw/Aniki::Plugin::PagerInjector/;

sub select_with_pager {
    my ($self, $table_name, $where, $opt) = @_;
    $opt //= {};

    my $page = $opt->{page} or Carp::croak("required parameter: page");
    my $rows = $opt->{rows} or Carp::croak("required parameter: rows");
    my $result = $self->select($table_name => $where, {
        %$opt,
        limit  => $rows + 1,
        offset => $rows * ($page - 1),
    });

    return $self->inject_pager_to_result($result => {
        rows => $rows,
        page => $page,
    });
}


1;
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Plugin::Pager - SELECT with pager

=head1 SYNOPSIS

    package MyDB;
    use Mouse v2.4.5;
    extends qw/Aniki/;
    with qw/Aniki::Plugin::Pager/;

    package main;
    my $db = MyDB->new(...);
    my $result = $db->select_with_pager('user', { type => 2 }, { page => 1, rows => 10 }); # => Aniki::Result::Collection(+Aniki::Result::Role::Pager)
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
