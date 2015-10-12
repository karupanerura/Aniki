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
        ;
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
