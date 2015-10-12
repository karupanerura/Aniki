package SampleTeng::DB::Schema;
use strict;
use warnings;
use DBI qw/:sql_types/;
use Teng::Schema::Declare;

table {
    name 'author';
    pk   qw/id/;
    columns
        { name => 'id', type => SQL_INTEGER }, # INTEGER
        { name => 'name', type => SQL_VARCHAR }, # VARCHAR
        { name => 'message', type => SQL_VARCHAR }, # VARCHAR
    ;

    inflate name => sub {
        my $name = shift;
        return uc $name;
    };

    deflate name => sub {
        my $name = shift;
        return lc $name;
    };
};

table {
    name 'module';
    pk   qw/id/;
    columns
        { name => 'id', type => SQL_INTEGER }, # INTEGER
        { name => 'name', type => SQL_VARCHAR }, # VARCHAR
        { name => 'author_id', type => SQL_INTEGER }, # INTEGER
    ;
};

1;
