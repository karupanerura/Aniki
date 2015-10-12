package Aniki::QueryBuilder::Canonical {
    use strict;
    use warnings;
    use utf8;

    use parent qw/Aniki::QueryBuilder/;

    sub insert {
        my ($self, $table, $values, $opt) = @_;
        if (ref $values eq 'HASH') {
            $values = [
                map { $_ => $values->{$_} } sort keys %$values
            ];
        }
        return $self->SUPER::insert($table, $values, $opt);
    }

    sub update {
        my ($self, $table, $args, $where) = @_;
        if (ref $args eq 'HASH') {
            $args = [
                map { $_ => $args->{$_} } sort keys %$args
            ];
        }
        if (ref $where eq 'HASH') {
            $where = [
                map { $_ => $where->{$_} } sort keys %$where
            ];
        }
        return $self->SUPER::update($table, $args, $where);
    }

    sub delete :method {
        my ($self, $table, $where, $opt) = @_;
        if (ref $where eq 'HASH') {
            $where = [
                map { $_ => $where->{$_} } sort keys %$where
            ];
        }
        return $self->SUPER::delete($table, $where, $opt);
    }

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
