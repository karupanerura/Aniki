use 5.014002;
package Aniki::Schema::Relation {
    use namespace::sweep;
    use Mouse;
    use Hash::Util::FieldHash qw/fieldhash/;
    use Aniki::Schema::Relation::Fetcher;

    has name => (
        is       => 'ro',
        required => 1,
    );

    has table_name => (
        is       => 'ro',
        required => 1,
    );

    has has_many => (
        is       => 'ro',
        required => 1,
    );

    has src => (
        is       => 'ro',
        required => 1,
    );

    has dest => (
        is       => 'ro',
        required => 1,
    );

    has _fetcher => (
        is      => 'ro',
        default => sub {
            fieldhash my %fetcher;
            return \%fetcher;
        },
    );

    sub fetcher {
        my ($self, $handler) = @_;
        return $self->_fetcher->{$handler} if exists $self->_fetcher->{$handler};
        return $self->_fetcher->{$handler} = Aniki::Schema::Relation::Fetcher->new(relation => $self, handler => $handler);
    }
}

1;
__END__
