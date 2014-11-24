use 5.014002;
package Aniki::Filter::Declare {
    use strict;
    use warnings;
    use utf8;

    use Aniki::Filter;

    sub import {
        my $class  = shift;
        my $caller = caller;

        my $filter = Aniki::Filter->new;

        no strict qw/refs/; ## no critic
        *{"${caller}::table"}   = \&_table;
        *{"${caller}::inflate"} = _inflate($filter);
        *{"${caller}::deflate"} = _deflate($filter);
    }

    our $TARGET_TABLE;

    sub _table ($&) {## no critic
        my ($table, $code) = @_;
        local $TARGET_TABLE = $table;
        $code->();
    }

    sub _inflate {
        my $filter = shift;
        return sub ($&) {## no critic
            my ($column, $code) = @_;
            if (defined $TARGET_TABLE) {
                $filter->add_table_inflator($TARGET_TABLE, $column, $code);
            }
            else {
                $filter->add_global_inflator($column, $code);
            }
        };
    }

    sub _deflate {
        my $filter = shift;
        sub ($&) {## no critic
            my ($column, $code) = @_;
            if (defined $TARGET_TABLE) {
                $filter->add_table_deflator($TARGET_TABLE, $column, $code);
            }
            else {
                $filter->add_global_deflator($column, $code);
            }
        };
    }
}

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Filter::Declare - TODO

=head1 SYNOPSIS

    use Aniki::Filter::Declare;

=head1 DESCRIPTION

TODO

=head1 SEE ALSO

L<perl>

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
