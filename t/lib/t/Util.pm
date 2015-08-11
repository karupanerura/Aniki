package t::Util;
use strict;
use warnings;
use feature qw/state/;

use parent qw/Test::Builder::Module/;
our @EXPORT = qw/query_count/;

use t::DB;
use t::DB::Schema;
use DBD::SQLite;

sub db {
    state $db = create_db();
    return $db;
}

sub create_db {
    my $db = t::DB->new(connect_info => ['dbi:SQLite:dbname=:memory:', '', '']);
    $db->execute($_) for split /;/, t::DB::Schema->output;
    return $db;
}

sub query_count (&) {## no critic
    my $code = shift;

    my $count = 0;
    no warnings qw/once redefine/;
    local *Aniki::execute = do {
        use warnings qw/once redefine/;
        my $super = \&Aniki::execute;
        sub {
            my $self = shift;
            my $sql  = shift;
            __PACKAGE__->builder->diag($sql) if $ENV{AUTHOR_TESTING};
            $count++;
            return $self->$super($sql, @_);
        };
    };
    use warnings qw/once redefine/;

    $code->();

    return $count;
}

1;
__END__
