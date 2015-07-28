use strict;
use warnings;
use utf8;

use Test::More;

use Aniki::Schema::Relationship;

is Aniki::Schema::Relationship::_to_plural("hero"), "heroes";
is Aniki::Schema::Relationship::_to_plural("child"), "children";
is Aniki::Schema::Relationship::_to_plural("my_news"), "my_news";
is Aniki::Schema::Relationship::_to_plural("my child"), "my children";

done_testing();
