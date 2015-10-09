use 5.014002;
package Aniki::Schema::Relationship::Fetcher {
    use namespace::sweep;
    use Mouse v2.4.5;

    has handler => (
        is       => 'ro',
        weak_ref => 1,
        required => 1,
    );

    has relationship => (
        is       => 'ro',
        weak_ref => 1,
        required => 1,
    );

    use List::MoreUtils qw/pairwise notall/;
    use List::UtilsBy qw/partition_by/;
    use SQL::QueryMaker;

    sub execute {
        my ($self, $rows, $relay) = @_;
        return unless @$rows;

        my $relationship = $self->relationship;
        my $name         = $relationship->name;
        my $table_name   = $relationship->dest_table_name;
        my $has_many     = $relationship->has_many;
        my @src_columns  = @{ $relationship->src_columns  };
        my @dest_columns = @{ $relationship->dest_columns };

        if (@src_columns == 1 and @dest_columns == 1) {
            my $src_column  = $src_columns[0];
            my $dest_column = $dest_columns[0];

            my @related_rows = $self->handler->select($table_name => {
                $dest_column => sql_in([grep defined, map { $_->get_column($src_column) } @$rows])
            }, { relay => $relay })->all;

            my %related_rows_map = partition_by { $_->get_column($dest_column) } @related_rows;
            for my $row (@$rows) {
                my $src_value = $row->get_column($src_column);
                next unless defined $src_value;

                my $related_rows = $related_rows_map{$src_value};
                $row->relay_data->{$name} = $has_many ? $related_rows : $related_rows->[0];
            }

            $self->_execute_inverse(\@related_rows => $rows);
        }
        else {
            # follow slow case...
            my $handler = $self->handler;
            for my $row (@$rows) {
                next if notall { defined $row->get_column($_) } @src_columns;
                my @related_rows = $handler->select($table_name => {
                    pairwise { $a => $row->get_column($b) } @dest_columns, @src_columns
                }, { relay => $relay })->all;
                $row->relay_data->{$name} = $has_many ? \@related_rows : $related_rows[0];
            }
        }
    }

    sub _execute_inverse {
        my ($self, $src_rows, $dest_rows) = @_;
        return unless @$src_rows;
        return unless @$dest_rows;

        for my $relationship ($self->relationship->get_inverse_relationships) {
            my $name         = $relationship->name;
            my $has_many     = $relationship->has_many;
            my @src_columns  = @{ $relationship->src_columns  };
            my @dest_columns = @{ $relationship->dest_columns };

            my $src_keygen = sub {
                my $src_row = shift;
                return join '|', map { quotemeta $src_row->get_column($_) } @src_columns;
            };
            my $dest_keygen = sub {
                my $dest_row = shift;
                return join '|', map { quotemeta $dest_row->get_column($_) } @dest_columns;
            };

            my %dest_rows_map = partition_by { $dest_keygen->($_) } @$dest_rows;
            for my $src_row (@$src_rows) {
                next if notall { defined $src_row->get_column($_) } @src_columns;
                my $dest_rows = $dest_rows_map{$src_keygen->($src_row)};
                $src_row->relay_data->{$name} = $has_many ? $dest_rows : $dest_rows->[0];
            }
        }
    }
}

1;
__END__
