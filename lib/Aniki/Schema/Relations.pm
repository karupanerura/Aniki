use 5.014002;
package Aniki::Schema::Relations {
    use namespace::sweep;
    use Moo;
    use Lingua::EN::Inflect qw/PL/;
    use SQL::Translator::Schema::Constants;

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
        my ($self, %rule) = @_;
        exists $rule{has_many}
            or $rule{has_many} = $self->schema->has_many($rule{table_name}, $rule{dest});
        exists $rule{name}
            or $rule{name} = $rule{has_many} ? PL($rule{table_name}) : $rule{table_name};

        my $name = $rule{name};
        exists $self->rule->{$name}
            or die "already exists $name in rule. (table:@{[ $self->table->name ]})";
        $self->rule->{$name} = \%rule;
    }

    sub add_by_constraint {
        my ($self, $constraint) = @_;
        die "Invalid constraint: $constraint" if $constraint->type ne FOREIGN_KEY;

        if ($constraint->table->name eq $self->table->name) {
            $self->add(
                name       => $constraint->name,
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

    sub get_relation_names {
        my $self = shift;
        return keys %{ $self->rules };
    }

    sub get_relations {
        my $self = shift;
        return map { $self->get_relation($_) } $self->get_relation_names;
    }

    sub get_relation {
        my ($self, $name) = @_;
        return unless exists $self->rule->{$name};
        return $self->rule->{$name};
    }
}

1;
__END__
