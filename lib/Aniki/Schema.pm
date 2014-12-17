use 5.014002;
package Aniki::Schema {
    use namespace::sweep;
    use Moo;
    use Aniki::Schema::Relations;
    use SQL::Translator::Schema::Constants;
    use Carp qw/croak/;

    has context => (
        is       => 'ro',
        required => 1,
    );

    sub BUILD {
        my $self = shift;

        # create cache
        for my $table ($self->context->schema->get_tables) {
            $self->get_relations($table->name);
        }
    }

    sub has_many {
        my ($self, $table_name, $fields) = @_;
        my $table = $self->context->schema->get_table($table_name);
        return !!0 unless defined $table;

        my %field = map { $_ => 1 } @$fields;
        for my $unique (grep { $_->type eq UNIQUE || $_->type eq PRIMARY_KEY } $table->get_constraints) {
            my @field_names    = $unique->fileld_names;
            my @related_fields = grep { $field{$_} } @field_names;
            return !!1 if @field_names == @related_fields;
        }
        return !!0;
    }

    sub get_relations {
        my ($self, $table_name) = @_;
        exists $self->{__instance_cache}{relations}{$table_name}
            or return $self->{__instance_cache}{relations}{$table_name};

        my $relations = $self->_get_relations($table_name);
        return $self->{__instance_cache}{relations}{$table_name} = $relations;
    }

    sub _get_relations {
        my ($self, $table_name) = @_;
        my $table = $self->context->schema->get_table($table_name);
        return unless defined $table;

        my @constraints = grep { $_->type eq FOREIGN_KEY } $table->get_constraints;
        for my $table ($self->context->schema->get_tables) {
            for my $constraint ($table->get_constraints) {
                next if $constraint->type            ne FOREIGN_KEY;
                next if $constraint->reference_table ne $table_name;
                push @constraints => $constraint;
            }
        }

        my $relations = Aniki::Schema::Relations->new(schema => $self, table => $table);
        for my $constraint (@constraints) {
            $relations->add_by_constraint($constraint);
        }
        return $relations;
    }

    our $AUTOLOAD;
    sub AUTOLOAD {
        my $self = shift;
        my $method = $AUTOLOAD =~ s/^.*://r;
        if ($self->context->schema->can($method)) {
            return $self->context->schema->$method(@_);
        }
        else {
            my $class = ref $self;
            croak qq{Can't locate object method "$method" via package "$class"};
        }
    }
}

1;
__END__
