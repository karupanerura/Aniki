package Aniki::Types {
    use strict;
    use warnings;
    use utf8;

    use Type::Tiny;
    use Scalar::Util qw/reftype blessed/;

    my $NAMESPACE = __PACKAGE__;
    my %STASH;

    sub type { _type($_[1]) }

    sub _type {
        my $name = shift;
        die "Undefined type: $name" unless exists $STASH{$name};
        return $STASH{$name};
    }

    sub _deftype {
        my ($name, $args) = @_;
        $STASH{$name} = Type::Tiny->new(
            name => "${NAMESPACE}::$name",
            %$args,
        );
    }

    _deftype Defined => {
        constraint => sub { defined $_ },
    };

    _deftype ArrayRef => {
        constraint => sub { reftype $_ && reftype $_ eq 'ARRAY' },
        parent     => _type('Defined'),
    };

    _deftype ConnectInfo => {
        parent => _type('ArrayRef'),
    };
};

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Types - TODO

=head1 SYNOPSIS

    use Aniki::Types;

=head1 DESCRIPTION

TODO

=head1 SEE ALSO

L<perl>

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
