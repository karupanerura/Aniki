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

    has row_data => (
        is       => 'ro',
        required => 1,
    );

    sub get {
        my ($self, $column) = @_;
        return $self->{__instance_cache}{get}{$column} if exists $self->{__instance_cache}{get}{$column};

        my $data = $self->get_column($column);
        return $self->{__instance_cache}{get}{$column} = $self->filter->inflate_column($self->table_name, $column, $data);
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
        else {
            my $msg = sprintf q{Can't locate object method "%s" via package "%s"}, $column, ref $self;
            croak $msg;
        }
    }
};

1;
