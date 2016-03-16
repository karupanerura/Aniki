package Aniki::QueryBuilder;
use 5.014002;

use strict;
use warnings;

use Carp ();

use SQL::Maker 1.19;
use parent qw/SQL::Maker/;

use SQL::Maker::Util ();
use List::MoreUtils qw/any indexes/;

__PACKAGE__->load_plugin('InsertMulti');
__PACKAGE__->load_plugin('InsertOnDuplicate');

sub select :method {
    my $self = shift;
    my ($table, $fields, $where, $opt) = @_;
    $opt //= {};

    # use default logic
    return $self->SUPER::select(@_) unless defined @{$opt}{qw/prefix limit offset/};
    return $self->SUPER::select(@_) if ref $where eq 'HASH'  && any { ref $_ } values %$where;
    return $self->SUPER::select(@_) if ref $where eq 'ARRAY' && any { ref $_ } indexes { $_ % 2 == 0 } @$where;

    unless (ref $fields eq 'ARRAY') {
        Carp::croak("SQL::Maker::select_query: \$fields should be ArrayRef[Str]");
    }

    my $prefix = $opt->{prefix} || 'SELECT ';

    my ($quote_char, $name_sep) = map { $self->$_ } qw/quote_char name_sep/;
    my $fields_sql = join ',', map { SQL::Maker::Util::quote_identifier($_, $quote_char, $name_sep) } @$fields;
    my $table_sql  = SQL::Maker::Util::quote_identifier($table, $quote_char, $name_sep);

    my $sql = "$prefix $fields_sql FROM $table_sql";
    my @bind;

    if (my @where = ref $where eq 'HASH' ? %$where : @$where) {
        $sql .= ' WHERE ';
        while (my ($field, $value) = splice @where, 0, 2) {
            my $field_sql = SQL::Maker::Util::quote_identifier($field, $quote_char, $name_sep);
            $sql .= "($field_sql = ?)";
            $sql .= ' AND ' if @where;
            push @bind => $value;
        }
    }

    $sql .= sprintf ' LIMIT %d',  $opt->{limit}  if $opt->{limit};
    $sql .= sprintf ' OFFSET %d', $opt->{offset} if $opt->{offset};

    return ($sql, @bind);
}

1;
__END__
