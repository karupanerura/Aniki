package Aniki::Plugin::PagerInjector;
use 5.014002;

use namespace::autoclean;
use Mouse::Role;
use Data::Page::NoTotalEntries;
use Aniki::Result::Role::Pager;

requires qw/guess_result_class/;

sub inject_pager_to_result {
    my ($self, $result, $opt) = @_;
    my $table_name = $result->table_name;

    my $has_next = $opt->{rows} < $result->count;
    if ($has_next) {
        my $result_class = ref $result;
        $result = $result_class->new(
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
        entries_per_page     => $opt->{rows},
        current_page         => $opt->{page},
        has_next             => $has_next,
        entries_on_this_page => $result->count,
    );
    $result->meta->does_role('Aniki::Result::Role::Pager')
        or Mouse::Util::apply_all_roles($result, 'Aniki::Result::Role::Pager');
    $result->pager($pager);

    return $result;
}

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Plugin::PagerInjector - plus one pager injector

=head1 SYNOPSIS

    package MyDB;
    use Mouse v2.4.5;
    extends qw/Aniki/;
    with qw/Aniki::Plugin::PagerInjector/;

    package main;
    my $db = MyDB->new(...);

    my ($page, $rows) = (1, 10);
    my ($limit, $offset) = ($rows + 1, ($page - 1) * $rows);
    my $result = $db->select('user', { type => 2 }, { limit => $limit, offset => $offset }); # => Aniki::Result::Collection
    $result = $db->inject_pager_to_result($result => { # => inject Aniki::Result::Role::Pager
        table_name => 'user',
        rows       => $rows,
        page       => $page,
    })
    $result->pager; # => Data::Page::NoTotalEntries

=head1 SEE ALSO

L<perl>
L<Data::Page::NoTotalEntries>

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
