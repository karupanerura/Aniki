package MyProj::DB::Filter {
    use Aniki::Filter::Declare;
    use Scalar::Util qw/blessed/;
    use Time::Moment;

    # define inflate/deflate filters in table context.
    table author => sub {
        inflate name => sub {
            my $name = shift;
            return uc $name;
        };

        deflate author => name => sub {
            my $name = shift;
            return lc $name;
        };
    };

    inflate qr/_at$/ => sub {
        my $datetime = shift;
        $datetime =~ tr/ /T/;
        $datetime .= 'Z';
        return Time::Moment->from_string($datetime);
    };

    deflate qr/_at$/ => sub {
        my $datetime = shift;
        return $datetime->at_utc->strftime('%F %T') if blessed $datetime and $datetime->isa('Time::Moment');
        return $datetime;
    };
};

1;
__END__
