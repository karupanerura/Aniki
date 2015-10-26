use 5.014002;

package Aniki::Handler::WeightedRoundRobin {
    use namespace::sweep;
    use Mouse;
    extends qw/Aniki::Handler/;

    use DBI ();
    use DBIx::Handler;
    use Data::WeightedRoundRobin;
    use Scalar::Util qw/refaddr/;

    around BUILDARGS => sub {
        my $orig = shift;
        my $self = shift;
        my %args = (@_ == 1 && ref $_[0] eq 'HASH') ? %{$_[0]} : @_;

        my $connect_info = delete $args{connect_info};
        my $rr = Data::WeightedRoundRobin->new([
            map {
                +{
                    %$_,
                    key => refaddr($_->{value}),
                }
            } @$connect_info
        ]);
        return $self->$orig(rr => $rr);
    };

    has rr => (
        is       => 'ro',
        required => 1,
    );

    has '+connect_info' => (
        is       => 'rw',
        required => 0,
        lazy     => 1,
        builder  => sub { shift->rr->next },
        clearer  => '_reset_connect_info',
    );

    sub is_connect_error {
        my ($self, $e) = @_;
        my ($dsn) = @{ $self->connect_info };
        my (undef, $driver) = DBI->parse_dsn($dsn);

        if ($driver eq 'mysql') {
            return $e =~ /\Qfailed: Can't connect to MySQL server on/m;
        }
        elsif ($driver eq 'Pg') {
            return $e =~ /\Qfailed: could not connect to server: Connection refused/m;
        }
        elsif ($driver eq 'Oracle') {
            # TODO: patches wellcome :p
        }

        warn "Unsupported dirver: $driver";
        return 0;
    }

    sub disconnect {
        my $self = shift;
        $self->_reset_connect_info();
        $self->SUPER::disconnect();
    }

    for my $name (__PACKAGE__->_proxy_methods) {
        __PACKAGE__->meta->add_around_method_modifier($name => sub {
            my $orig = shift;
            my $self = shift;
            my @args = @_;

            # context proxy
            my @ret;
            my $wantarray = wantarray;
            if (not defined $wantarray) {
                eval { $self->$orig(@args) };
            }
            elsif ($wantarray) {
                @ret = eval { $self->$orig(@args) };
            }
            else {
                $ret[0] = eval { $self->$orig(@args) };
            }

            if (my $e = $@) {
                my $key = refaddr($self->connect_info);
                my $in_txn = !$self->handler->in_txn;
                $self->disconnect;
                if ($self->is_connect_error($e) && $in_txn) {
                    # retry
                    my $guard = $self->rr->save;
                    $self->rr->remove($key);
                    if ($self->rr->next) {
                        warn "RETRY: $e";
                        return $self->$name(@_);
                    }
                }
                die $e;
            }

            return $wantarray ? @ret : $ret[0];
        });
    }

    __PACKAGE__->meta->make_immutable();
}

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Handler::RoundRobin - Round robin database handler manager

=head1 METHODS

=head2 CLASS METHODS

=head3 C<new(%args) : Aniki::Handler::RoundRobin>

Create instance of Aniki::Handler.

=head4 Arguments

=over 4

=item C<connect_info : ArrayRef[HashRef]>

Auguments for L<Data::WeightedRoundRobin>'s C<new> method.

Example:

    [
        {
            value  => [...], # Auguments for DBI's connect method.
            weight => 10,
        },
    ]

=item on_connect_do : CodeRef|ArrayRef[Str]|Str
=item on_disconnect_do : CodeRef|ArrayRef[Str]|Str

Execute SQL or CodeRef when connected/disconnected.
