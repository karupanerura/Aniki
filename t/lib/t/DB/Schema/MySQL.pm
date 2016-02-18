package t::DB::Schema::MySQL;
use strict;
use warnings;

use DBIx::Schema::DSL;

use t::DB::Schema::Common ();
our $CONTEXT = t::DB::Schema::Common->context->clone;
__PACKAGE__->context->schema->database(database 'MySQL');

sub relationship_rules { t::DB::Schema::Common->relationship_rules }

1;
