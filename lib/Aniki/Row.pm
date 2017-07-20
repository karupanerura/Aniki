package Aniki::Row;
use 5.014002;

use namespace::autoclean;
use Mouse v2.4.5;
use Carp qw/croak/;

has table_name => (
    is       => 'ro',
    required => 1,
);

has row_data => (
    is       => 'ro',
    required => 1,
);

has is_new => (
    is      => 'rw',
    default => 0,
);

has relay_data => (
    is      => 'ro',
    default => sub { +{} },
);

my %handler;

sub BUILD {
    my ($self, $args) = @_;
    $handler{0+$self} = delete $args->{handler};
}

sub handler { $handler{0+shift} }
sub schema  { shift->handler->schema }
sub filter  { shift->handler->filter }

sub table {
    my $self = shift;
    return $self->handler->schema->get_table($self->table_name);
}

sub get {
    my ($self, $column) = @_;
    return $self->{__instance_cache}{get}{$column} if exists $self->{__instance_cache}{get}{$column};

    return undef unless exists $self->row_data->{$column}; ## no critic

    my $data = $self->get_column($column);
    return $self->{__instance_cache}{get}{$column} = $self->filter->inflate_column($self->table_name, $column, $data);
}

sub relay {
    my ($self, $key) = @_;
    unless (exists $self->relay_data->{$key}) {
        $self->relay_data->{$key} = $self->relay_fetch($key);
    }

    my $relay_data = $self->relay_data->{$key};
    return unless defined $relay_data;
    return wantarray ? @$relay_data : $relay_data if ref $relay_data eq 'ARRAY';
    return $relay_data;
}

sub relay_fetch {
    my ($self, $key) = @_;
    $self->handler->fetch_and_attach_relay_data($self->table_name, [$key], [$self]);
    return $self->relay_data->{$key};
}

sub is_prefetched {
    my ($self, $key) = @_;
    return exists $self->relay_data->{$key};
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

sub refetch {
    my ($self, $opts) = @_;
    $opts //= +{};
    $opts->{limit} = 1;

    my $where = $self->handler->_where_row_cond($self->table, $self->row_data);
    return $self->handler->select($self->table_name => $where, $opts)->first;
}

my %accessor_method_cache;
sub _accessor_method_cache {
    my $self = shift;
    return $accessor_method_cache{$self->table_name} //= {};
}

sub _guess_accessor_method {
    my ($invocant, $method) = @_;

    if (ref $invocant) {
        my $self   = $invocant;
        my $column = $method;

        my $cache = $self->_accessor_method_cache();
        return $cache->{$column} if exists $cache->{$column};

        return $cache->{$column} = sub { shift->get($column) } if exists $self->row_data->{$column};

        my $relationships = $self->table->get_relationships;
        return $cache->{$column} = sub { shift->relay($column) } if $relationships && $relationships->get($column);
    }

    return undef; ## no critic
}

sub can {
    my ($invocant, $method) = @_;
    my $code = $invocant->SUPER::can($method);
    return $code if defined $code;
    return $invocant->_guess_accessor_method($method);
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $invocant = shift;
    my $column = $AUTOLOAD =~ s/^.+://r;

    if (ref $invocant) {
        my $self = $invocant;
        my $method = $self->_guess_accessor_method($column);
        return $self->$method(@_) if defined $method;
    }

    my $msg = sprintf q{Can't locate object method "%s" via package "%s"}, $column, ref $invocant || $invocant;
    croak $msg;
}

sub DEMOLISH {
    my $self = shift;
    delete $handler{0+$self};
}

__PACKAGE__->meta->make_immutable();
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Row - Row class

=head1 SYNOPSIS

    my $result = $db->select(foo => { bar => 1 });
    for my $row ($result->all) {
        print $row->id, "\n";
    }

=head1 DESCRIPTION

This is row class.

=head1 INSTANCE METHODS

=head2 C<$column()>

Autoload column name method to C<< $row->get($column) >>.

=head2 C<$relay()>

Autoload relationship name method to C<< $row->relay($column) >>.

=head2 C<get($column)>

Returns column data.

=head2 C<relay($name)>

Returns related data.
If not yet cached, call C<relay_fetch>.

=head2 C<relay_fetch($name)>

Fetch related data, and returns related data.

=head2 C<is_prefetched($name)>

If a pre-fetch has been executed, it return a true value.

=head2 C<get_column($column)>

Returns column data without inflate filters.

=head2 C<get_columns()>

Returns columns data as hash reference.

=head2 C<refetch()>

=head1 ACCESSORS

=over 4

=item C<handler : Aniki>

=item C<schema : Aniki::Schema>

=item C<table : Aniki::Schema::Table>

=item C<filter : Aniki::Filter>

=item C<table_name : Str>

=item C<is_new : Bool>

=item C<row_data : HashRef>

=item C<relay_data : HashRef>

=back

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
