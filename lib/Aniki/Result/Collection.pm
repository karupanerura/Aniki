package Aniki::Result::Collection {
    use namespace::sweep;
    use Mouse v2.4.5;
    use overload
        '@{}'    => sub { shift->rows },
        fallback => 1;

    has table_name => (
        is       => 'ro',
        required => 1,
    );

    has handler => (
        is       => 'ro',
        required => 1,
        weak_ref => 1,
    );

    has row_datas => (
        is       => 'ro',
        required => 1,
    );

    has inflated_rows => (
        is      => 'ro',
        lazy    => 1,
        builder => '_inflate',
    );

    has suppress_row_objects => (
        is      => 'rw',
        default => sub { shift->handler->suppress_row_objects },
    );

    has row_class => (
        is      => 'rw',
        default => sub {
            my $self = shift;
            $self->handler->guess_row_class($self->table_name);
        },
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

This is result class of C<SELECT> query.

You can use original result class:

    package MyApp::DB;
    use Mouse;
    extends qw/Aniki/;

    __PACKAGE__->setup(
        schema => 'MyApp::DB::Schema',
        result => 'MyApp::DB::Collection',
    );

And it auto detect the collection class by C<MyApp::DB::Collection>.

=head1 SEE ALSO

L<perl>

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
