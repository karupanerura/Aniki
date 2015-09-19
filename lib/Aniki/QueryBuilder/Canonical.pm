package Aniki::QueryBuilder::Canonical {
    use strict;
    use warnings;
    use utf8;

    use parent qw/Aniki::QueryBuilder/;

    sub select_query {
        my ($self, $table, $fields, $where, $opt) = @_;
        if (ref $where eq 'HASH') {
            $where = [
                map { $_ => $where->{$_} } sort keys %$where
            ];
        }
        return $self->SUPER::select_query($table, $fields, $where, $opt);
    }
}

1;
__END__
