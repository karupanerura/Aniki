package Aniki::Schema::Relationship::Declare;
use strict;
use warnings;
use utf8;

use B::Hooks::EndOfScope;
use DBIx::Schema::DSL ();
use Aniki::Schema::Relationship;

my %RULES;

sub import {
    my $caller = caller;
    {
        no strict qw/refs/;
        *{"${caller}::relationship_rules"} = sub { $RULES{$caller} };
        *{"${caller}::relation"} = \&_relation;
        *{"${caller}::relay_to"} = \&_relay_to;
        *{"${caller}::relay_by"} = \&_relay_by;
    }
    on_scope_end {
        no strict qw/refs/;
        no warnings qw/redefine/;
        *{"${caller}::create_table"} = \&_create_table;
    };
}

my %TABLE_NAME;

sub _create_table ($$) {## no critic
    my ($table_name, $code) = @_;
    my $caller = caller;
    $TABLE_NAME{$caller} = $table_name;
    goto \&DBIx::Schema::DSL::create_table;
}

sub _relation {
    my ($src_columns, $dest_table_name, $dest_columns, %opt) = @_;
    my $caller = caller;
    my $src_table_name = $TABLE_NAME{$caller};
    push @{ $RULES{$caller} } => {
        src_table_name  => $src_table_name,
        src_columns     => $src_columns,
        dest_table_name => $dest_table_name,
        dest_columns    => $dest_columns,
        %opt,
    };
}

sub _relay_to {
    my $dest_table_name = shift;
    my $caller = caller;
    my $src_columns    = ["${dest_table_name}_id"];
    my $dest_columns   = ['id'];
    @_ = ($src_columns, $dest_table_name, $dest_columns, @_);
    goto \&_relation;
}

sub _relay_by {
    my $dest_table_name = shift;
    my $caller = caller;
    my $src_table_name = $TABLE_NAME{$caller};
    my $src_columns    = ['id'];
    my $dest_columns   = ["${src_table_name}_id"];
    @_ = ($src_columns, $dest_table_name, $dest_columns, @_);
    goto \&_relation;
}

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Aniki::Schema::Relationship::Declare - DSL for declaring relationship rules

=head1 SYNOPSIS

    use 5.014002;
    package MyProj::DB::Schema {
        use DBIx::Schema::DSL;
        use Aniki::Schema::Relationship::Declare;

        create_table 'module' => columns {
            integer 'id', primary_key, auto_increment;
            varchar 'name';
            integer 'author_id';

            add_index 'author_id_idx' => ['author_id'];

            relay_to 'author', name => '';
        };

        create_table 'author' => columns {
            integer 'id', primary_key, auto_increment;
            varchar 'name', unique;

            relay_by 'module';
        };
    };

    1;

=head1 FUNCTIONS

=over 4

=item C<relay_to>

=item C<relay_by>

=item C<relation>

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
