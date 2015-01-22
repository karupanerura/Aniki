use 5.014002;
package Aniki::Filter {
    use namespace::sweep;
    use Mouse;

    has global_inflators => (
        is      => 'ro',
        default => sub { [] },
    );

    has global_deflators => (
        is      => 'ro',
        default => sub { [] },
    );

    has table_inflators => (
        is      => 'ro',
        default => sub { +{} },
    );

    has table_deflators => (
        is      => 'ro',
        default => sub { +{} },
    );

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
};

1;
__END__
