package t::Util;
use strict;
use warnings;
use feature qw/state/;

use parent qw/Test::Builder::Module/;
our @EXPORT = qw/db run_on_database run_on_each_databases run_on_all_databases query_count/;

use t::DB;

our $DB;
sub db () { $DB } ## no critic

sub run_on_database (&) {## no critic
    my $code = shift;

    my @databases = $ENV{AUTHOR_TESTING} ? t::DB->all_databases : qw/SQLite/;
    t::DB->run_on_each_databases(\@databases => sub {
        my $class = shift;
        local $DB = $class->new();
        $code->();
    });
}

sub run_on_each_databases ($&) {## no critic
    my ($databases, $code) = @_;
    t::DB->run_on_each_databases($databases => sub {
        my $class = shift;
        local $DB = $class->new();
        $code->();
    });
}

sub run_on_all_databases (&) {## no critic
    my $code = shift;
    t::DB->run_on_all_databases(sub {
        my $class = shift;
        local $DB = $class->new();
        $code->();
    });
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
