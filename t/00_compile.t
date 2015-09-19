use strict;
use Test::More 0.98;

for (<DATA>) {
    chomp;
    use_ok $_;
}

done_testing;

__DATA__
Aniki
Aniki::Collection
Aniki::Collection::Role::Pager
Aniki::Filter
Aniki::Filter::Declare
Aniki::Plugin::Count
Aniki::Plugin::Pager
Aniki::QueryBuilder
Aniki::QueryBuilder::Canonical
Aniki::Row
Aniki::Schema
Aniki::Schema::Relationship
Aniki::Schema::Relationship::Declare
Aniki::Schema::Relationship::Fetcher
Aniki::Schema::Relationships
