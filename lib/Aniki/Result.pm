package Aniki::Result;
use 5.014002;

use namespace::autoclean;
use Mouse v2.4.5;

has table_name => (
    is       => 'ro',
    required => 1,
);

has suppress_row_objects => (
    is      => 'rw',
    lazy    => 1,
    default => sub { shift->handler->suppress_row_objects },
);

has row_class => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->handler->guess_row_class($self->table_name);
    },
);

my %handler;

sub BUILD {
    my ($self, $args) = @_;
    $handler{0+$self} = delete $args->{handler};
}

sub handler { $handler{0+shift} }

sub DEMOLISH {
    my $self = shift;
    delete $handler{0+$self};
}

__PACKAGE__->meta->make_immutable();
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Result - Result class

=head1 SYNOPSIS

    my $result = $db->select(foo => { bar => 1 });

=head1 DESCRIPTION

This is abstract result class.

Aniki detect the collection class from root result class by table name.
Default root result class is C<MyApp::DB::Collection>.

You can use original result class:

    package MyApp::DB;
    use Mouse;
    extends qw/Aniki/;

    __PACKAGE__->setup(
        schema => 'MyApp::DB::Schema',
        result => 'MyApp::DB::Collection',
    );

=head1 ACCESSORS

=over 4

=item C<handler : Aniki>

=item C<table_name : Str>

=item C<suppress_row_objects : Bool>

=item C<row_class : ClassName>

=back

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
