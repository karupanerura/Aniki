package Aniki::Result {
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
};

1;
__END__
