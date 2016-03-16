package Aniki::Row::Mutable;
use 5.014002;

use namespace::sweep;
use Mouse v2.4.5;
use Carp qw/croak/;
use List::MoreUtils qw/any/;
extends qw/Aniki::Row/;

has _old_row_data => (
    is      => 'rw',
    default => sub { +{} },
);

# override
sub _guess_accessor_method {
    my ($invocant, $method) = @_;

    if (ref $invocant) {
        my $self   = $invocant;
        my $column = $method;

        my $cache = $self->_accessor_method_cache();
        return $cache->{$column} if exists $cache->{$column};

        if ($self->table->has_column($column)) {
            return $cache->{$column} = sub {
                my $self = shift;
                return @_ ? $self->set($column => @_) : $self->get($column);
            };
        }
    }

    return $invocant->SUPER::_guess_accessor_method($method);
}

sub is_dirty { !!%{ shift->_old_row_data } }

sub set {
    my $self = shift;
    if (@_ == 1 && ref $_[0] eq 'HASH') {
        my %columns = %{ $_[0] };
        for my $column (keys %columns) {
            $self->set($column, $columns{$column});
        }
        return;
    }

    my ($column, $value) = @_;
    my $raw_value = $self->filter->deflate_column($self->table_name, $column, $value);
    $self->set_column($column, $raw_value);
    $self->{__instance_cache}{get}{$column} = $value;
    return $value;
}

sub set_column {
    my ($self, $column, $value) = @_;
    $self->_old_row_data->{$column} //= $self->row_data->{$column};
    $self->row_data->{$column} = $value;
    delete $self->{__instance_cache}{get}{$column};
    if (my @names = keys %{ $self->relay_data }) {
        my $relationships = $self->table->get_relationships;
        for my $relationship (map { $relationships->get($_) } @names) {
            delete $self->relay_data->{$relationship->name}
                if any { $_ eq $column } @{ $relationship->src_columns };
        }
    }
    return $value;
}

sub set_columns {
    my ($self, $columns) = @_;
    for my $column (keys %$columns) {
        $self->set_column($column, $columns->{$column});
    }
    return;
}

sub update {
    my $self = shift;
    my %set = @_ == 1 && ref $_[0] eq 'HASH' ? %{$_[0]} : @_;
    $self->set(\%set) if %set;
    return 0E0 unless $self->is_dirty;

    my %update = map { $_ => $self->row_data->{$_} } keys %{ $self->_old_row_data };
    my $ret = $self->handler->update($self => \%update);
    $self->_old_row_data({});
    return $ret;
}

{
    # define alias
    no warnings qw/once/;
    *save = \&update;
}

sub delete :method {
    my $self = shift;
    return $self->handler->delete($self);
}

sub withdraw {
    my $self = shift;
    my %old = %{ $self->_old_row_data };
    return !!0 unless %old;

    for my $column (keys %old) {
        $self->row_data->{$column} = $old{$column};
        delete $self->{__instance_cache}{get}{$column};
    }
    return !!1;
}

__PACKAGE__->meta->make_immutable();
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Row::Mutable - Mutable row class

=head1 SYNOPSIS

    my $result = $db->select(foo => { bar => 1 });
    for my $row ($result->all) {
        print $row->id, "\n";
        $row->id(2);
        $row->update(); # or $row->withdraw();
    }

=head1 DESCRIPTION

This is mutable row class.

=head2 WARNING

The mutable row is B<BAD PLACTICE>.
But, some cases requires mutable row. (e.g. legacy sotfware)
If you don't require row object as mutable, you should *NOT* use it.

=head1 INSTANCE METHODS

=head2 C<$column($value)>

Autoload column name method to C<< $row->set($column => $value) >>.

=head2 C<set($column => $value)>

Set column data.

=head2 C<set(\%values)>

Set columns data as hash reference.

=head2 C<set_column($column => $value)>

Set column data without deflate filters.

=head2 C<set_columns(\%values)>

Set columns data as hash reference without deflate filters.

=head2 C<update()>

=head2 C<save()>

Update the changes to apply to database.

=head2 C<delete()>

Delete this row from database.

=head2 C<withdraw()>

Withdraw the changes.

=head1 ACCESSORS

=over 4

=item C<is_dirty : Bool>

Does this row has any changes?

=back

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
