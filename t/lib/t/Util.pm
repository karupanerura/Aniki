package t::Util;
use strict;
use warnings;
use feature qw/state/;

use t::DB;
use t::DB::Schema;

sub db {
    state $db = create_db();
    return $db;
}

sub create_db {
    my $db = t::DB->new(connect_info => ['dbi:SQLite:dbname=:memory:', '', '']);
    $db->execute($_) for split /;/, t::DB::Schema->output;
    return $db;
}

1;
__END__
