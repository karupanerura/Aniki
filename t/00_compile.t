use strict;
use Test::More 0.98;

for (<DATA>) {
    chomp;
    use_ok $_;
}

done_testing;

__DATA__
Aniki
Aniki::Filter
Aniki::Filter::Declare
Aniki::QueryBuilder
Aniki::QueryBuilder::Canonical
Aniki::Result
Aniki::Result::Collection
Aniki::Result::Collection::Joined
Aniki::Result::Role::Pager
Aniki::Row
Aniki::Row::Joined
Aniki::Schema
Aniki::Schema::Relationship
Aniki::Schema::Relationship::Declare
Aniki::Schema::Relationship::Fetcher
Aniki::Schema::Relationships
Aniki::Schema::Table
Aniki::Schema::Table::Field
Aniki::Schema::Table::PrimaryKey
