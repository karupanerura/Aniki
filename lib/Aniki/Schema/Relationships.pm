use 5.014002;
package Aniki::Schema::Relationships {
    use namespace::sweep;
    use Mouse;
    use SQL::Translator::Schema::Constants;
    use Aniki::Schema::Relationship;

    has schema => (
        is       => 'ro',
        required => 1,
        weak_ref => 1,
    );

    has table => (
        is       => 'ro',
        required => 1,
    );

    has rule => (
        is      => 'rw',
        default => sub { +{} },
    );

    sub add {
        my $self = shift;
        my $relationship = Aniki::Schema::Relationship->new(schema => $self->schema, @_);

        my $name = $relationship->name;
        exists $self->rule->{$name}
            and die "already exists $name in rule. (table:@{[ $self->table->name ]})";
        $self->rule->{$name} = $relationship;
    }

    sub add_by_constraint {
        my ($self, $constraint) = @_;
        die "Invalid constraint: $constraint" if $constraint->type ne FOREIGN_KEY;

        if ($constraint->table->name eq $self->table->name) {
            $self->add(
                table_name => $constraint->reference_table,
                src        => [$constraint->field_names],
                dest       => [$constraint->reference_fields],
            );
        }
        elsif ($constraint->reference_table eq $self->table->name) {
            $self->add(
                table_name => $constraint->table->name,
                src        => [$constraint->reference_fields],
                dest       => [$constraint->field_names],
            );
        }
        else {
            die "Invalid constraint: $constraint";
        }
    }

    sub get_relationship_names {
        my $self = shift;
        return keys %{ $self->rules };
    }

    sub get_relationships {
        my $self = shift;
        return map { $self->get_relationship($_) } $self->get_relationship_names;
    }

    sub get_relationship {
        my ($self, $name) = @_;
        return unless exists $self->rule->{$name};
        return $self->rule->{$name};
    }
}

1;
__END__
