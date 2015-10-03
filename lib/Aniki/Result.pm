package Aniki::Result {
    use namespace::sweep;
    use Mouse v2.4.5;
    use Hash::Util qw/fieldhash/;

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

    fieldhash my %handler;

    around new => sub {
        my $orig = shift;
        my ($class, %args) = @_;
        my $handler = delete $args{handler};
        my $self = $class->$orig(%args);
        $handler{$self} = $handler;
        return $self;
    };

    sub handler { $handler{+shift} }
};

1;
__END__
