package Aniki::Plugin::RangeConditionMaker;
use 5.014002;

use namespace::sweep;
use Mouse::Role;

use Carp qw/carp croak/;
use SQL::QueryMaker qw/sql_gt sql_lt sql_and/;

sub make_range_condtion {
    carp '[INCOMPATIBLE CHANGE Aniki@1.02] This method is renamed to make_range_condition. the old method is removed at 1.03.';
    shift->make_range_condition(@_);
}

sub make_range_condition {
    my ($self, $range) = @_;

    my %total_range_condition;
    for my $type (qw/lower upper gt lt/) {
        next unless exists $range->{$type};

        ref $range->{$type} eq 'HASH'
            or croak "$type condition *MUST* be HashRef.";

        my $func = $type eq 'lower' || $type eq 'gt' ? \&sql_gt
                 : $type eq 'upper' || $type eq 'lt' ? \&sql_lt
                 : die "Unknown type: $type";

        my $range_condition = $range->{$type};
        for my $column (keys %$range_condition) {
            croak "$column cannot be a reference value for range condition"
                if ref $range_condition->{$column};

            my $condition = $func->($range_condition->{$column});
            $total_range_condition{$column} =
                exists $total_range_condition{$column} ? sql_and([$total_range_condition{$column}, $condition])
                                                       : $condition;
        }
    }

    return %total_range_condition ? \%total_range_condition : undef;
}

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Plugin::RangeConditionMaker - range condition maker

=head1 SYNOPSIS

    package MyDB;
    use Mouse v2.4.5;
    extends qw/Aniki/;
    with qw/Aniki::Plugin::RangeConditionMaker/;

    package main;
    my $db = MyDB->new(...);

    my $where = $db->make_range_condition({ upper => { id => 10 } });
    # => { id => { '<' => 10 } }
    $where = $db->make_range_condition({ lower => { id => 0 } });
    # => { id => { '>' =>  0 } }
    $where = $db->make_range_condition({ upper => { id => 10 }, lower => { id => 0 } });
    # => { id => [-and => { '>' => 0 }, { '<' => 10 }] }

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
