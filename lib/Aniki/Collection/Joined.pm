package Aniki::Collection::Joined {
    use namespace::sweep;
    use Mouse v2.4.5;
    extends qw/Aniki::Collection/;

    use Carp qw/croak/;
    use Aniki::Row::Joined;
    use List::MoreUtils qw/none/;
    use List::UtilsBy qw/uniq_by/;
    use Scalar::Util qw/refaddr/;

    has '+table_name' => (
        required => 0,
        lazy     => 1,
        default  => sub { join ',', @{ $_[0]->table_names } }
    );

    has '+row_class' => (
        lazy    => 1,
        default => sub { croak 'Cannot get row class of '.__PACKAGE__.'. Use row_classes instead of row_class.' },
    );

    has table_names => (
        is       => 'ro',
        required => 1,
    );

    has _compact_row_datas => (
        is      => 'ro',
        lazy    => 1,
        builder => '_compress',
    );

    has _collection_cache => (
        is      => 'ro',
        default => sub {
            my $self = shift;
            return +{
                map { $_ => undef } @{ $self->table_names },
            };
        },
    );

    sub row_classes {
        my $self = shift;
        return map { $self->handler->guess_row_class($_) } @{ $self->table_names };
    }

    sub rows {
        my $self = shift;
        if (@_ == 1) {
            my $table_name = shift;
            return $self->collection($table_name)->rows();
        }
        return $self->SUPER::rows();
    }

    sub collection {
        my ($self, $table_name) = @_;
        return $self->_collection_cache->{$table_name} if $self->_collection_cache->{$table_name};

        my $result_class = $self->handler->guess_result_class($table_name);
        return $self->_collection_cache->{$table_name} = $result_class->new(
            table_name           => $table_name,
            handler              => $self->handler,
            row_datas            => [uniq_by { refaddr $_ } map { $_->{$table_name} } @{ $self->_compact_row_datas() }],
            !$self->suppress_row_objects ? (
                inflated_rows    => [uniq_by { refaddr $_ } map { $_->$table_name   } @{ $self->inflated_rows() }],
            ) : (),
            suppress_row_objects => $self->suppress_row_objects,
        );
    }

    sub _uniq_key {
        my ($row_data, $pk) = @_;
        return if none { defined $row_data->{$_} } @$pk;
        return join '|', map { quotemeta $row_data->{$_} } @$pk;
    }

    sub _compress {
        my $self = shift;
        my $handler = $self->handler;

        my @table_names = @{ $self->table_names };
        my %pk = map {
            $_ => [map { $_->name }  $handler->schema->get_table($_)->primary_key->fields]
        } @table_names;

        my @rows;
        my %cache;
        for my $row (@{ $self->row_datas }) {
            my %rows;

            for my $table_name (@table_names) {
                my $row_data = $row->{$table_name};
                my $uniq_key = _uniq_key($row_data, $pk{$table_name});
                $rows{$table_name} = defined $uniq_key ? ($cache{$table_name}{$uniq_key} ||= $row_data) : $row_data;
            }

            push @rows => \%rows;
        }

        return \@rows;
    }

    sub _inflate {
        my $self = shift;
        my $handler = $self->handler;

        my @table_names = @{ $self->table_names };
        my %row_class = map { $_ => $handler->guess_row_class($_) } @table_names;

        my @rows;
        my %cache;
        for my $row (@{ $self->_compact_row_datas }) {
            my %rows;

            # inflate to row class
            for my $table_name (@table_names) {
                my $row_data = $row->{$table_name};
                $rows{$table_name} = $cache{$table_name}{refaddr $row_data} ||= $row_class{$table_name}->new(
                    table_name => $table_name,
                    handler    => $handler,
                    row_data   => $row_data,
                );
            }

            push @rows => Aniki::Row::Joined->new(values %rows);
        }

        return \@rows;
    }
};

1;
__END__
