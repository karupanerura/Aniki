package Aniki::Plugin::WeightedRoundRobin;
use 5.014002;

use namespace::sweep;
use Mouse::Role;

use Aniki::Handler::WeightedRoundRobin;

sub handler_class { 'Aniki::Handler::WeightedRoundRobin' }

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Plugin::WeightedRoundRobin - Connect to database in a Weighted RoundRobin manner

=head1 SYNOPSIS

    package MyDB;
    use Mouse v2.4.5;
    extends qw/Aniki/;
    with qw/Aniki::Plugin::WeightedRoundRobin/;

    my $db = MyDB->new(connect_info => [
        {
            value  => [...], # Auguments for DBI's connect method.
            weight => 10,
        },
        {
            value  => [...], # Auguments for DBI's connect method.
            weight => 10,
        },
    ]);

=head1 SEE ALSO

L<Data::WeightedRoundRobin>
L<Aniki::Handler::WeightedRoundRobin>

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
