package Aniki::Row {
    use namespace::sweep;
    use Mouse;
    use Carp qw/croak/;
    # $Carp::Internal{+__PACKAGE__}++;

    has table_name => (
        is       => 'ro',
        required => 1,
    );

    has handler => (
        is       => 'ro',
        required => 1,
        weak_ref => 1,
    );

    has schema => (
        is      => 'ro',
        default => sub { shift->handler->schema },
    );

    has filter => (
        is      => 'ro',
        default => sub { shift->handler->filter },
    );

    has row_data => (
        is       => 'ro',
        required => 1,
    );

    has table => (
        is       => 'ro',
        default  => sub {
            my $self = shift;
            return $self->schema->get_table($self->table_name);
        },
    );

    has relations => (
        is      => 'ro',
        default => sub {
            my $self = shift;
            $self->schema->get_relations($self->table_name);
        },
    );

    has relay_data => (
        is      => 'ro',
        default => sub { +{} },
    );

    sub get {
        my ($self, $column) = @_;
        return $self->{__instance_cache}{get}{$column} if exists $self->{__instance_cache}{get}{$column};

        my $data = $self->get_column($column);
        return $self->{__instance_cache}{get}{$column} = $self->filter->inflate_column($self->table_name, $column, $data);
    }

    sub relay {
        my ($self, $key) = @_;
        unless (exists $self->relay_data->{$key}) {
            $self->relay_data->{$key} = $self->relay_fetch($key);
        }

        my $relay_data = $self->relay_data->{$key};
        return if not defined $relay_data;
        return wantarray ? @$relay_data : $relay_data if ref $relay_data eq 'ARRAY';
        return $relay_data;
    }

    sub relay_fetch {
        my ($self, $key) = @_;
        $self->handler->attach_relay_data($self->table_name, [$key], [$self]);
        return $self->relay_data->{$key};
    }

    sub get_column {
        my ($self, $column) = @_;
        return undef unless exists $self->row_data->{$column}; ## no critic
        return $self->row_data->{$column};
    }

    sub get_columns {
        my $self = shift;

        my %row;
        for my $column (keys %{ $self->row_data }) {
            $row{$column} = $self->row_data->{$column};
        }
        return \%row;
    }

    our $AUTOLOAD;
    sub AUTOLOAD {
        my $self   = shift;
        my $column = $AUTOLOAD =~ s/^.+://r;
        if (exists $self->row_data->{$column}) {
            return $self->get($column);
        }
        elsif ($self->relations && $self->relations->get_relation($column)) {
            return $self->relay($column);
        }
        else {
            my $msg = sprintf q{Can't locate object method "%s" via package "%s"}, $column, ref $self;
            croak $msg;
        }
    }
};

1;
