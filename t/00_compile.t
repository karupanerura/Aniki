use strict;
use Test::More 0.98;

use_ok $_ for qw(
    Aniki
    Aniki::Collection
    Aniki::Filter
    Aniki::Filter::Declare
    Aniki::QueryBuilder
    Aniki::Row
    Aniki::Schema
    Aniki::Schema::Relationship
    Aniki::Schema::Relationship::Fetcher
    Aniki::Schema::Relationships
);

done_testing;

