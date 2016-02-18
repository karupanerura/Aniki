package t::DB::Exception;
use strict;
use warnings;

use Scalar::Util qw/blessed/;

sub new {
    my $class = shift;
    return bless {@_} => $class;
}

sub message { shift->{message} }

sub throw { die shift->new(@_) }

sub caught {
    my ($class, $e) = @_;
    return blessed $e && $e->isa($class);
}

1;
__END__
