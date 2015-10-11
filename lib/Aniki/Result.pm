package Aniki::Result {
    use namespace::sweep;
    use Mouse v2.4.5;

    has table_name => (
        is       => 'ro',
        required => 1,
    );

    has suppress_row_objects => (
        is      => 'rw',
        lazy    => 1,
        default => sub { shift->handler->suppress_row_objects },
    );

    has row_class => (
        is      => 'rw',
        lazy    => 1,
        default => sub {
            my $self = shift;
            $self->handler->guess_row_class($self->table_name);
        },
    );

    my %handler;

    sub BUILD {
        my ($self, $args) = @_;
        $handler{0+$self} = delete $args->{handler};
    }

    sub handler { $handler{0+shift} }

    sub DEMOLISH {
        my $self = shift;
        delete $handler{0+$self};
    }

    __PACKAGE__->meta->make_immutable();
};

1;
__END__
