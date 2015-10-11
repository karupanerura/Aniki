package Aniki::Schema::Table {
    use namespace::sweep;
    use Mouse v2.4.5;
    use Carp qw/croak/;
    use Aniki::Schema::Relationships;
    use Aniki::Schema::Table::Field;
    use Aniki::Schema::Table::PrimaryKey;
    use SQL::Translator::Schema::Constants;

    has _schema => (
        is       => 'ro',
        required => 1,
        weak_ref => 1,
    );

    has _table => (
        is       => 'ro',
        required => 1,
    );

    has name => (
        is      => 'ro',
        default => sub { shift->_table->name },
    );

    has relationships => (
        is      => 'ro',
        default => \&_setup_relationships,
    );

    has primary_key => (
        is      => 'ro',
        default => sub { Aniki::Schema::Table::PrimaryKey->new(shift->_table->primary_key) },
    );

    has _fields_cache => (
        is      => 'ro',
        default => sub {
            my $self = shift;
            return [
                map { Aniki::Schema::Table::Field->new($_) } $self->_table->get_fields
            ]
        },
    );

    has _fields_map_cache => (
        is      => 'ro',
        default => sub {
            my $self = shift;
            return {
                map { $_->name => $_ } @{ $self->_fields_cache }
            }
        },
    );

    sub BUILDARGS {
        my ($class, $table, $schema) = @_;
        return $class->SUPER::BUILDARGS(_table => $table, _schema => $schema);
    }

    sub get_fields { @{ shift->_fields_cache } }

    sub get_field {
        my ($self, $name) = @_;
        return unless exists $self->_fields_map_cache->{$name};
        return $self->_fields_map_cache->{$name}
    }

    sub get_relationships { shift->relationships }

    sub _setup_relationships {
        my $self = shift;

        my @constraints = grep { $_->type eq FOREIGN_KEY } $self->get_constraints;
        for my $table ($self->_schema->context->schema->get_tables) {
            for my $constraint ($table->get_constraints) {
                next if $constraint->type            ne FOREIGN_KEY;
                next if $constraint->reference_table ne $self->name;
                push @constraints => $constraint;
            }
        }

        my $relationships = Aniki::Schema::Relationships->new(schema => $self->_schema, table => $self);
        for my $constraint (@constraints) {
            $relationships->add_by_constraint($constraint);
        }

        if ($self->_schema->schema_class->can('relationship_rules')) {
            my $rules = $self->_schema->schema_class->relationship_rules;
            for my $rule (@$rules) {
                next if $rule->{src_table_name} ne $self->_table->name;
                $relationships->add(%$rule);
            }
        }

        return $relationships;
    }

    our $AUTOLOAD;
    sub AUTOLOAD {
        my $self = shift;
        my $method = $AUTOLOAD =~ s/^.*://r;
        if ($self->_table->can($method)) {
            return $self->_table->$method(@_);
        }

        my $class = ref $self;
        croak qq{Can't locate object method "$method" via package "$class"};
    }

    __PACKAGE__->meta->make_immutable();
};

1;
__END__
