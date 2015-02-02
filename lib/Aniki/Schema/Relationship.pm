use 5.014002;
package Aniki::Schema::Relationship {
    use namespace::sweep;
    use Mouse;
    use Hash::Util::FieldHash qw/fieldhash/;
    use Aniki::Schema::Relationship::Fetcher;
    use Lingua::EN::Inflect qw/PL/;

    has schema => (
        is       => 'ro',
        required => 1,
        weak_ref => 1,
    );

    has table_name => (
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

    has has_many => (
        is      => 'ro',
        default => sub {
            my $self = shift;
            return $self->schema->has_many($self->table_name, $self->dest);
        },
    );

    has name => (
        is       => 'ro',
        default  => \&_guess_name,
    );

    has _fetcher => (
        is      => 'ro',
        default => sub {
            fieldhash my %fetcher;
            return \%fetcher;
        },
    );

    sub _guess_name {
        my $self = shift;

        my @src        = @{ $self->src };
        my $table_name = $self->table_name;

        my $prefix = @src == 1 && $src[0] =~ /^(.+)_\Q$table_name/ ? $1.'_' : '';
        my $name   = $self->has_many ? PL($table_name) : $table_name;
        return $prefix . $name;
    }

    sub fetcher {
        my ($self, $handler) = @_;
        return $self->_fetcher->{$handler} if exists $self->_fetcher->{$handler};
        return $self->_fetcher->{$handler} = Aniki::Schema::Relationship::Fetcher->new(relationship => $self, handler => $handler);
    }
}

1;
__END__
