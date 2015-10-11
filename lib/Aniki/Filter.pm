use 5.014002;
package Aniki::Filter {
    use namespace::sweep;
    use Mouse v2.4.5;

    has global_inflators => (
        is      => 'ro',
        default => sub { [] },
    );

    has global_deflators => (
        is      => 'ro',
        default => sub { [] },
    );

    has global_triggers => (
        is      => 'ro',
        default => sub { +{} },
    );

    has table_inflators => (
        is      => 'ro',
        default => sub { +{} },
    );

    has table_deflators => (
        is      => 'ro',
        default => sub { +{} },
    );

    has table_triggers => (
        is      => 'ro',
        default => sub { +{} },
    );

    sub _identity { $_[0] }
    sub _normalize_column2rx { ref $_[0] eq 'Regexp' ? $_[0] : qr/\A\Q$_[0]\E\z/m }

    sub add_global_inflator {
        my ($self, $column, $code) = @_;
        my $rx = _normalize_column2rx($column);
        push @{ $self->global_inflators } => [$rx, $code];
    }

    sub add_global_deflator {
        my ($self, $column, $code) = @_;
        my $rx = _normalize_column2rx($column);
        push @{ $self->global_deflators } => [$rx, $code];
    }

    sub add_global_trigger {
        my ($self, $event, $code) = @_;
        push @{ $self->global_triggers->{$event} } => $code;
    }

    sub add_table_inflator {
        my ($self, $table_name, $column, $code) = @_;
        my $rx = _normalize_column2rx($column);
        push @{ $self->table_inflators->{$table_name} } => [$rx, $code];
    }

    sub add_table_deflator {
        my ($self, $table_name, $column, $code) = @_;
        my $rx = _normalize_column2rx($column);
        push @{ $self->table_deflators->{$table_name} } => [$rx, $code];
    }

    sub add_table_trigger {
        my ($self, $table_name, $event, $code) = @_;
        push @{ $self->table_triggers->{$table_name}->{$event} } => $code;
    }

    sub inflate_column {
        my ($self, $table_name, $column, $data) = @_;
        my $code = $self->get_inflate_callback($table_name, $column);
        return $data unless defined $code;
        return $code->($data);
    }

    sub deflate_column {
        my ($self, $table_name, $column, $data) = @_;
        my $code = $self->get_deflate_callback($table_name, $column);
        return $data unless defined $code;
        return $code->($data);
    }

    sub inflate_row {
        my ($self, $table_name, $row) = @_;
        my %row = %$row;
        for my $column (keys %row) {
            $row{$column} = $self->inflate_column($table_name, $column, $row{$column});
        }
        return \%row;
    }

    sub deflate_row {
        my ($self, $table_name, $row) = @_;
        my %row = %$row;
        for my $column (keys %row) {
            $row{$column} = $self->deflate_column($table_name, $column, $row{$column});
        }
        return \%row;
    }

    sub apply_trigger {
        my ($self, $event, $table_name, $row) = @_;
        my %row = %$row;

        my $trigger = $self->get_trigger_callback($event, $table_name);
        return $trigger->(\%row);
    }

    sub get_inflate_callback {
        my ($self, $table_name, $column) = @_;
        unless (exists $self->{__inflate_callbacks_cache}->{$table_name}->{$column}) {
            my $callback;
            for my $pair (@{ $self->global_inflators }) {
                my ($rx, $code) = @$pair;
                $callback = $code if $column =~ $rx;
            }
            for my $pair (@{ $self->table_inflators->{$table_name} }) {
                my ($rx, $code) = @$pair;
                $callback = $code if $column =~ $rx;
            }
            $self->{__inflate_callbacks_cache}->{$table_name}->{$column} = $callback;
        }
        return $self->{__inflate_callbacks_cache}->{$table_name}->{$column};
    }

    sub get_deflate_callback {
        my ($self, $table_name, $column) = @_;
        unless (exists $self->{__deflate_callbacks_cache}->{$table_name}->{$column}) {
            my $callback;
            for my $pair (@{ $self->global_deflators }) {
                my ($rx, $code) = @$pair;
                $callback = $code if $column =~ $rx;
            }
            for my $pair (@{ $self->table_deflators->{$table_name} }) {
                my ($rx, $code) = @$pair;
                $callback = $code if $column =~ $rx;
            }
            $self->{__deflate_callbacks_cache}->{$table_name}->{$column} = $callback;
        }
        return $self->{__deflate_callbacks_cache}->{$table_name}->{$column};
    }

    sub get_trigger_callback {
        my ($self, $event, $table_name) = @_;

        unless (exists $self->{__trigger_callback_cache}->{$table_name}->{$event}) {
            my @triggers = (
                @{ $self->table_triggers->{$table_name}->{$event} || [] },
                @{ $self->global_triggers->{$event} || [] },
            );

            my $trigger = \&_identity;
            for my $cb (reverse @triggers) {
                my $next = $trigger;
                $trigger = sub { $cb->($_[0], $next) };
            }
            $self->{__trigger_callback_cache}->{$table_name}->{$event} = $trigger;
        }

        return $self->{__trigger_callback_cache}->{$table_name}->{$event};
    }

    __PACKAGE__->meta->make_immutable();
};

1;
__END__
