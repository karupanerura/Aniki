package t::DB::Filter;
use strict;
use warnings;
use utf8;

use Aniki::Filter::Declare;

table author => sub {
    inflate 'inflate_message' => sub {
        my $value = shift;
        return "inflate $value";
    };
    deflate 'deflate_message' => sub {
        my $value = shift;
        return "deflate $value";
    };
};

1;
__END__
