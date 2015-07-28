use 5.014002;
package Aniki::Schema::Relationship {
    use namespace::sweep;
    use Mouse;
    use Hash::Util::FieldHash qw/fieldhash/;
    use Aniki::Schema::Relationship::Fetcher;
    use Lingua::EN::Inflect qw/PL/;

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
            fieldhash my %fetcher;
            return \%fetcher;
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
        return $words =~ s/(?<=$sep)(.+?)$/PL($1)/er;
    }

    sub fetcher {
        my ($self, $handler) = @_;
        return $self->_fetcher->{$handler} if exists $self->_fetcher->{$handler};
        return $self->_fetcher->{$handler} = Aniki::Schema::Relationship::Fetcher->new(relationship => $self, handler => $handler);
    }
}

1;
__END__
