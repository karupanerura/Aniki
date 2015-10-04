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
        *{"${caller}::table"}    = \&_table;
        *{"${caller}::inflate"}  = _inflate($filter);
        *{"${caller}::deflate"}  = _deflate($filter);
        *{"${caller}::trigger"}  = _trigger($filter);
        *{"${caller}::instance"} = _instance($filter);
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

    sub _trigger {
        my $filter = shift;
        sub ($&) {## no critic
            my ($event, $code) = @_;
            if (defined $TARGET_TABLE) {
                $filter->add_table_trigger($TARGET_TABLE, $event, $code);
            }
            else {
                $filter->add_global_trigger($event, $code);
            }
        };
    }

    sub _instance {
        my $filter = shift;
        return sub { $filter };
    }
}

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Filter::Declare - DSL for declaring actions on sometimes

=head1 SYNOPSIS

    package MyApp::DB::Filter;
    use strict;
    use warnings;

    use Aniki::Filter::Declare;

    use Scalar::Util qw/blessed/;
    use Time::Moment;
    use Data::GUID::URLSafe;

    # apply callback to row before insert
    trigger insert => sub {
        my ($row, $next) = @_;
        $row->{created_at} = Time::Moment->now;
        return $next->($row);
    };

    # define trigger/inflate/deflate filters in table context.
    table author => sub {
        trigger insert => sub {
            my ($row, $next) = @_;
            $row->{guid} = Data::GUID->new->as_base64_urlsafe;
            return $next->($row);
        };

        inflate name => sub {
            my $name = shift;
            return uc $name;
        };

        deflate name => sub {
            my $name = shift;
            return lc $name;
        };
    };

    # define inflate/deflate filters in global context. (apply to all tables)
    inflate qr/_at$/ => sub {
        my $datetime = shift;
        return Time::Moment->from_string($datetime.'Z', lenient => 1);
    };

    deflate qr/_at$/ => sub {
        my $datetime = shift;
        return $datetime->at_utc->strftime('%F %T') if blessed $datetime and $datetime->isa('Time::Moment');
        return $datetime;
    };

=head1 FUNCTIONS

=over 4

=item C<table>

=item C<inflate>

=item C<deflate>

=item C<trigger>

=back

=head1 SEE ALSO

L<perl>

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut
