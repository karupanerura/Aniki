use 5.014002;
package Aniki::Schema {
    use namespace::sweep;
    use Mouse v2.4.5;
    use Aniki::Schema::Relationships;
    use SQL::Translator::Schema::Constants;
    use Carp qw/croak/;

    has schema_class => (
        is       => 'ro',
        required => 1,
    );

    has context => (
        is      => 'ro',
        default => sub { shift->schema_class->context }
    );

    sub BUILD {
        my $self = shift;

        # create cache
        for my $table ($self->context->schema->get_tables) {
            $self->get_relationships($table->name);
        }
    }

    sub has_many {
        my ($self, $table_name, $fields) = @_;
        my $table = $self->context->schema->get_table($table_name);
        return !!1 unless defined $table;

        my %field = map { $_ => 1 } @$fields;
        for my $unique (grep { $_->type eq UNIQUE || $_->type eq PRIMARY_KEY } $table->get_constraints) {
            my @field_names    = $unique->field_names;
            my @related_fields = grep { $field{$_} } @field_names;
            return !!0 if @field_names == @related_fields;
        }
        return !!1;
    }

    sub get_relationships {
        my ($self, $table_name) = @_;
        exists $self->{__instance_cache}{relationships}{$table_name}
           and return $self->{__instance_cache}{relationships}{$table_name};

        my $relationships = $self->_get_relationships($table_name);
        return $self->{__instance_cache}{relationships}{$table_name} = $relationships;
    }

    sub _get_relationships {
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

        my $relationships = Aniki::Schema::Relationships->new(schema => $self, table => $table);
        for my $constraint (@constraints) {
            $relationships->add_by_constraint($constraint);
        }

        if ($self->schema_class->can('relationship_rules')) {
            my $rules = $self->schema_class->relationship_rules;
            for my $rule (@$rules) {
                next if $rule->{src_table_name} ne $table_name;
                $relationships->add(%$rule);
            }
        }

        return $relationships;
    }

    sub get_inverse_relationships_by_relationship {
        my ($self, $src) = @_;

        my @relationships;
        for my $dest ($self->get_relationships($src->dest_table_name)->get_relationships) {
            next if $dest->dest_table_name ne $src->src_table_name;
            next if not _cmp_deeply($dest->dest_columns, $src->src_columns);
            next if not _cmp_deeply($dest->src_columns,  $src->dest_columns);
            push @relationships => $dest;
        }

        return @relationships;
    }

    sub _cmp_deeply {
        my ($l, $r) = @_;
        return $l eq $r if not ref $l or not ref $r;
        return !!0      if ref $l ne ref $r;

        if (ref $l eq 'HASH') {
            for my $k (keys %$l) {
                return !!0 if not exists $r->{$k};
                return !!0 if not _cmp_deeply($l->{$k}, $r->{$k});
            }
            for my $k (keys %$r) {
                return !!0 if not exists $l->{$k};
            }
            return !!1;
        }
        elsif (ref $l eq 'ARRAY') {
            return !!0 if @$l != @$r;
            for my $i (0..$#{$l}) {
                return !!0 if not _cmp_deeply($l->[$i], $r->[$i]);
            }
            return !!1;
        }

        die "Unknwon case: $l cmp $r";
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

    __PACKAGE__->meta->make_immutable();
}

1;
__END__
