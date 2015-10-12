package Aniki::Schema::Table::Field {
    use namespace::sweep;
    use Mouse v2.4.5;

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

};

1;
__END__
