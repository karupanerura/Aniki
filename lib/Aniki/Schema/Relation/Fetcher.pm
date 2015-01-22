use 5.014002;
package Aniki::Schema::Relation::Fetcher {
    use namespace::sweep;
    use Mouse;

    has handler => (
        is       => 'ro',
        weak_ref => 1,
        required => 1,
    );

    has relation => (
        is       => 'ro',
        weak_ref => 1,
        required => 1,
    );

    use List::MoreUtils qw/pairwise/;
    use List::UtilsBy qw/partition_by/;

    sub execute {
        my ($self, $rows) = @_;
        return unless @$rows;

        my $relation     = $self->relation;
        my $name         = $relation->name;
        my $table_name   = $relation->table_name;
        my $has_many     = $relation->has_many;
        my @src_columns  = @{ $relation->src  };
        my @dest_columns = @{ $relation->dest };

        if (@src_columns == 1 and @dest_columns == 1) {
            my $src_column  = $src_columns[0];
            my $dest_column = $dest_columns[0];

            my %related_rows_map = partition_by {
                $_->get_column($dest_column)
            } $self->handler->select($table_name => {
                $dest_column => [map { $_->get_column($src_column) } @$rows]
            })->all;

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
                })->all;
                $row->relay_data->{$name} = $has_many ? \@related_rows : $related_rows[0];
            }
        }
    }
}

1;
__END__
