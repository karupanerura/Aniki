package Aniki::Row::Joined {
    use strict;
    use warnings;

    use Carp qw/croak/;

    sub new {
        my ($class, @rows) = @_;
        my %rows = map { $_->table_name => $_ } @rows;
        return bless \%rows => $class;
    }

    sub can {
        my ($invocant, $method) = @_;
        my $code = $invocant->SUPER::can($method);
        return $code if defined $code;

        if (ref $invocant) {
            my $self       = $invocant;
            my $table_name = $method;
            return sub { $self->{$table_name} } if exists $self->{$table_name};
        }

        return undef; ## no critic
    }

    our $AUTOLOAD;
    sub AUTOLOAD {
        my $invocant = shift;
        my $table_name = $AUTOLOAD =~ s/^.+://r;

        if (ref $invocant) {
            my $self = $invocant;
            return $self->{$table_name} if exists $self->{$table_name};
        }

        my $msg = sprintf q{Can't locate object method "%s" via package "%s"}, $table_name, ref $invocant || $invocant;
        croak $msg;
    }

    sub DESTROY {} # no autoload
};

1;
