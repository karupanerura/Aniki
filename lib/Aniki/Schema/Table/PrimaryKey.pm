package Aniki::Schema::Table::PrimaryKey;
use 5.014002;

use namespace::sweep;
use Mouse v2.4.5;
use Aniki::Schema::Table::Field;
use Carp qw/croak/;

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

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    my $method = $AUTOLOAD =~ s/^.*://r;
    if ($self->_primary_key->can($method)) {
        return $self->_primary_key->$method(@_);
    }

    my $class = ref $self;
    croak qq{Can't locate object method "$method" via package "$class"};
}

__PACKAGE__->meta->make_immutable;
__END__
