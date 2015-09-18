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

    use List::MoreUtils qw/pairwise/;
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

            my %related_rows_map = partition_by {
                $_->get_column($dest_column)
            } $self->handler->select($table_name => {
                $dest_column => sql_in([map { $_->get_column($src_column) } @$rows])
            }, { relay => $relay })->all;

            for my $row (@$rows) {
                my $related_rows = $related_rows_map{$row->get_column($src_column)};
                $row->relay_data->{$name} = $has_many ? $related_rows : $related_rows->[0];
            }
        }
        else {
            # follow slow case...
            # TODO: show warning
            my $handler = $self->handler;
            for my $row (@$rows) {
                my @related_rows = $handler->select($table_name => {
                    pairwise { $a => $row->get_column($b) } @dest_columns, @src_columns
                }, { relay => $relay })->all;
                $row->relay_data->{$name} = $has_many ? \@related_rows : $related_rows[0];
            }
        }
    }
}

1;
__END__
