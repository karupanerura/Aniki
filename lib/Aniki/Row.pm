package Aniki::Row {
    use namespace::sweep;
    use Moo;
    use Carp qw/croak/;

    has table_name => (
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

    has schema => (
        is       => 'ro',
        required => 1,
    );

    has filter => (
        is       => 'ro',
        required => 1,
    );

    has handler => (
        is       => 'ro',
        required => 1,
        weak_ref => 1,
    );

    has row_data => (
        is       => 'ro',
        required => 1,
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
        return $self->relay_data->{$key} if exists $self->relay_data->{$key};

        my $row = $self->relay_fetch($key);
        return $self->relay_data->{$key} = $row;
    }

    sub relay_fetch {
        my ($self, $key) = @_;
        my $relation = $self->schema->get_relations($self->table_name)->get_relation($key);
        return unless $relation;

        my ($related_row) = $self->select($relation->{table_name} => {
            map {
                $relation->{dest}->[$_] => $self->get_column($relation->{src}->[$_])
            } keys @{ $relation->{dest} }
        });

        return $related_row
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
        elsif (exists $self->relay_data->{$column}) {## FIXME
            return $self->relay($column);
        }
        else {
            my $msg = sprintf q{Can't locate object method "%s" via package "%s"}, $column, ref $self;
            croak $msg;
        }
    }
};

1;
