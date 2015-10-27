package Aniki::Schema::Table::Field;
use 5.014002;

use namespace::sweep;
use Mouse v2.4.5;
use Carp qw/croak/;

has _field => (
    is       => 'ro',
    required => 1,
);

has name => (
    is      => 'ro',
    default => sub { shift->_field->name },
);

has is_auto_increment => (
    is      => 'ro',
    default => sub { shift->_field->is_auto_increment },
);

has default_value => (
    is      => 'ro',
    default => sub { shift->_field->default_value },
);

has sql_data_type => (
    is      => 'ro',
    default => sub { shift->_field->sql_data_type },
);

sub BUILDARGS {
    my ($class, $field) = @_;
    return $class->SUPER::BUILDARGS(_field => $field);
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    my $method = $AUTOLOAD =~ s/^.*://r;
    if ($self->_field->can($method)) {
        return $self->_field->$method(@_);
    }

    my $class = ref $self;
    croak qq{Can't locate object method "$method" via package "$class"};
}

__PACKAGE__->meta->make_immutable;
__END__
