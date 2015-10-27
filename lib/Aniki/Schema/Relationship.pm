package Aniki::Schema::Relationship;
use 5.014002;

use namespace::sweep;
use Mouse v2.4.5;
use Aniki::Schema::Relationship::Fetcher;
use Lingua::EN::Inflect qw/PL/;
use Hash::Util::FieldHash qw/fieldhash/;

our @WORD_SEPARATORS = ('-', '_', ' ');

has schema => (
    is       => 'ro',
    required => 1,
    weak_ref => 1,
);

has src_table_name => (
    is       => 'ro',
    required => 1,
);

has src_columns => (
    is       => 'ro',
    required => 1,
);

has dest_table_name => (
    is       => 'ro',
    required => 1,
);

has dest_columns => (
    is       => 'ro',
    required => 1,
);

has has_many => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        return $self->schema->has_many($self->dest_table_name, $self->dest_columns);
    },
);

has name => (
    is       => 'ro',
    default  => \&_guess_name,
);

has _fetcher => (
    is      => 'ro',
    default => sub {
        fieldhash my %cache;
        return \%cache
    },
);

sub _guess_name {
    my $self = shift;

    my @src_columns     = @{ $self->src_columns };
    my @dest_columns    = @{ $self->dest_columns };
    my $src_table_name  = $self->src_table_name;
    my $dest_table_name = $self->dest_table_name;

    my $prefix = (@src_columns  == 1 && $src_columns[0]  =~ /^(.+)_\Q$dest_table_name/) ? $1.'_' :
                 (@dest_columns == 1 && $dest_columns[0] =~ /^(.+)_\Q$src_table_name/)  ? $1.'_' :
                 '';

    my $name = $self->has_many ? _to_plural($dest_table_name) : $dest_table_name;
    return $prefix . $name;
}

sub _to_plural {
    my $words = shift;
    my $sep = join '|', map quotemeta, @WORD_SEPARATORS;
    return $words =~ s/(?<=$sep)(.+?)$/PL($1)/er if $words =~ /$sep/;
    return PL($words);
}

sub fetcher {
    my ($self, $handler) = @_;
    return $self->_fetcher->{$handler} if exists $self->_fetcher->{$handler};
    return $self->_fetcher->{$handler} = Aniki::Schema::Relationship::Fetcher->new(relationship => $self, handler => $handler);
}

sub get_inverse_relationships {
    my $self = shift;
    return @{ $self->{__inverse_relationships} } if exists $self->{__inverse_relationships};

    my @inverse_relationships = $self->_get_inverse_relationships;
    $self->{__inverse_relationships} = \@inverse_relationships;
    return @inverse_relationships;
}

sub _get_inverse_relationships {
    my $self = shift;

    my @relationships;
    for my $dest ($self->schema->get_table($self->dest_table_name)->get_relationships->all) {
        next if $dest->dest_table_name ne $self->src_table_name;
        next if not _cmp_deeply($dest->dest_columns, $self->src_columns);
        next if not _cmp_deeply($dest->src_columns,  $self->dest_columns);
        push @relationships => $dest;
    }

    return @relationships;
}

sub _cmp_deeply {
    my ($l, $r) = @_;
    return $l eq $r if not ref $l or not ref $r;
    return !!0      if ref $l ne ref $r;

    if (ref $l eq 'HASH') {
        for my $k (keys %$l) {
            return !!0 if not exists $r->{$k};
            return !!0 if not _cmp_deeply($l->{$k}, $r->{$k});
        }
        for my $k (keys %$r) {
            return !!0 if not exists $l->{$k};
        }
        return !!1;
    }
    elsif (ref $l eq 'ARRAY') {
        return !!0 if @$l != @$r;
        for my $i (0..$#{$l}) {
            return !!0 if not _cmp_deeply($l->[$i], $r->[$i]);
        }
        return !!1;
    }

    die "Unknwon case: $l cmp $r";
}

__PACKAGE__->meta->make_immutable();
__END__
