package t::DB::Schema::SQLite;
use strict;
use warnings;

use DBIx::Schema::DSL;

use t::DB::Schema::Common ();
our $CONTEXT = t::DB::Schema::Common->context->clone;
__PACKAGE__->context->schema->database(database 'SQLite');

sub relationship_rules { t::DB::Schema::Common->relationship_rules }

1;
