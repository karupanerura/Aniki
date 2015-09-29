use 5.014002;

package Aniki::Plugin::Pager {
    use namespace::sweep;
    use Mouse::Role;
    use Data::Page::NoTotalEntries;
    use Aniki::Result::Role::Pager;

    requires qw/select result_class/;

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

        my $has_next = $rows < $result->count ? 1 : 0;
        if ($has_next) {
            $result = $self->result_class->new(
                table_name           => $table_name,
                handler              => $self,
                row_datas            => [@{$result->row_datas}[0..$result->count-2]],
                !$result->suppress_row_objects ? (
                    inflated_rows    => [@{$result->inflated_rows}[0..$result->count-2]],
                ) : (),
                suppress_row_objects => $result->suppress_row_objects,
                row_class            => $result->row_class,
            );
        }

        my $pager = Data::Page::NoTotalEntries->new(
            entries_per_page     => $rows,
            current_page         => $page,
            has_next             => $has_next,
            entries_on_this_page => $result->count,
        );
        $result->meta->does_role('Aniki::Result::Role::Pager')
            or Mouse::Util::apply_all_roles($result, 'Aniki::Result::Role::Pager');
        $result->pager($pager);

        return $result;
    }
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
    $db->select_with_pager('user', '*', {type => 2}); # => SELECT COUNT(*) FROM user WHERE type=2

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
