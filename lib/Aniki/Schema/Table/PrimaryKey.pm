package Aniki::Schema::Table::PrimaryKey {
    use namespace::sweep;
    use Mouse v2.4.5;
    use Aniki::Schema::Table::Field;

    has _primary_key => (
        is       => 'ro',
        required => 1,
    );

    has _fields => (
        is      => 'ro',
        default => sub {
            my $self = shift;
            return [
                map { Aniki::Schema::Table::Field->new($_) } $self->_primary_key->fields
            ];
        },
    );

    sub BUILDARGS {
        my ($class, $primary_key) = @_;
        return $class->SUPER::BUILDARGS(_primary_key => $primary_key);
    }

    sub fields { @{ shift->_fields } }
};

1;
__END__
