use 5.014002;

package Aniki::Plugin::SelectJoined {
    use namespace::sweep;
    use Mouse::Role;
    use Aniki::QueryBuilder;
    use Aniki::Collection::Joined;
    use Carp qw/croak/;

    requires qw/schema query_builder suppress_row_objects txn_manager execute/;

    Aniki::QueryBuilder->load_plugin('JoinSelect');

    sub select_joined {
        my ($self, $base_table, $join_conditions, $where, $opt) = @_;

        my @table_names = ($base_table);
        for (my $i = 0; my $table = $join_conditions->[$i]; $i += 2) {
            push @table_names => $table;
        }
        my @tables = map { $self->schema->get_table($_) } @table_names;

        my $name_sep = $self->query_builder->name_sep;
        my @fields;
        for my $table (@tables) {
            my $table_name = $table->name;
            push @fields =>
                map { "$table_name$name_sep$_" }
                map { $_->name } $table->get_fields();
        }

        my ($sql, @bind) = $self->query_builder->join_select($base_table, $join_conditions, \@fields, $where, $opt);
        return $self->select_joined_by_sql($sql, \@bind, {
            table_names => \@table_names,
            fields      => \@fields,
            %$opt,
        });
    }

    sub select_joined_by_sql {
        my ($self, $sql, $bind, $opt) = @_;
        $opt //= {};

        my $table_names = $opt->{table_names} or croak 'table_names is required';
        my $fields      = $opt->{fields}      or croak 'fields is required';
        my $relay       = exists $opt->{relay} ? $opt->{relay} : {};

        my $relay_enabled_fg = %$relay && !$self->suppress_row_objects;
        if ($relay_enabled_fg) {
            my $txn; $txn = $self->txn_scope unless $self->txn_manager->in_transaction;

            my $sth = $self->execute($sql, @$bind);
            my $result = $self->_fetch_joined_by_sth($sth, $table_names, $fields);

            for my $table_name (@$table_names) {
                my $rows  = $result->rows($table_name);
                my $relay = $relay->{$table_name};
                   $relay = [$relay] if ref $relay eq 'HASH';
                $self->attach_relay_data($table_name, $relay, $rows);
            }

            $txn->rollback if defined $txn; ## for read only
            return $result;
        }
        else {
            my $sth = $self->execute($sql, @$bind);
            return $self->_fetch_joined_by_sth($sth, $table_names, $fields);
        }
    }

    sub _fetch_joined_by_sth {
        my ($self, $sth, $table_names, $fields) = @_;
        my @rows;

        my %row;
        $sth->bind_columns(\@row{@$fields});
        push @rows => $self->_seperate_rows(\%row) while $sth->fetch;
        $sth->finish;

        return Aniki::Collection::Joined->new(
            table_names => $table_names,
            handler     => $self,
            row_datas   => \@rows,
        );
    }

    sub _seperate_rows {
        my ($self, $row) = @_;

        my $name_sep = quotemeta $self->query_builder->name_sep;

        my %rows;
        for my $full_named_column (keys %$row) {
            my ($table_name, $column) = split /$name_sep/, $full_named_column, 2;
            $rows{$table_name}{$column} = $row->{$full_named_column};
        }

        return \%rows;
    }
}

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Plugin::SelectJoined - Support for Joined query

=head1 SYNOPSIS

    package MyDB;
    use Mouse v2.4.5;
    extends qw/Aniki/;
    with qw/Aniki::Plugin::SelectJoined/;

    package main;
    my $db = MyDB->new(...);

    my $result = $db->select_joined(user_item => [
        user => {'user_item.user_id' => 'user.id'},
        item => {'user_item.item_id' => 'item.id'},
    ], {
        'user.id' => 2,
    }, {
        order_by => 'user_item.item_id',
    });

    for my $row ($result->all) {
        my $user_item = $row->user_item;
        my $user      = $row->user;
        my $item      = $row->item;

        ...
    }

=head1 DESCRIPTION

TODO

=head1 SEE ALSO

L<Teng::Plugin::SelectJoined>

L<SQL::Maker::Plugin::JoinSelect>

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
