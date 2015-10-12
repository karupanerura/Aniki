package Aniki::Result::Collection {
    use namespace::sweep;
    use Mouse v2.4.5;
    extends qw/Aniki::Result/;

    use overload
        '@{}'    => sub { shift->rows },
        fallback => 1;

    has row_datas => (
        is       => 'ro',
        required => 1,
    );

    has inflated_rows => (
        is      => 'ro',
        lazy    => 1,
        builder => '_inflate',
    );

    sub _inflate {
        my $self = shift;
        my $row_class  = $self->row_class;
        my $table_name = $self->table_name;
        my $handler    = $self->handler;
        return [
            map {
                $row_class->new(
                    table_name => $table_name,
                    handler    => $handler,
                    row_data   => $_
                )
            } @{ $self->row_datas }
        ];
    }

    sub rows {
        my $self = shift;
        return $self->suppress_row_objects ? $self->row_datas : $self->inflated_rows;
    }

    sub count { scalar @{ shift->rows(@_) } }

    sub first        { shift->rows(@_)->[0]  }
    sub last :method { shift->rows(@_)->[-1] }
    sub all          { @{ shift->rows(@_) }  }

    __PACKAGE__->meta->make_immutable();
};

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Result::Collection - Rows as a collection

=head1 SYNOPSIS

    my $result = $db->select(foo => { bar => 1 });
    for my $row ($result->all) {
        print $row->id, "\n";
    }

=head1 DESCRIPTION

This is collection result class.

=head1 INSTANCE METHODS

=head2 rows

Returns rows as array reference.

=head2 count

Returns rows count.

=head2 first

Returns first row.

=head2 last

Returns last row.

=head2 all

Returns rows as array.

=head1 ACCESSORS

=over 4

=item handler : Aniki

=item table_name : Str

=item suppress_row_objects : Bool

=item row_class : ClassName

=item row_datas : ArrayRef[HashRef]

=item inflated_rows : ArrayRef[Aniki::Row]

=back

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
