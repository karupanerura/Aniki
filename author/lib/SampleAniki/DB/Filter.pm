package SampleAniki::DB::Filter {
    use Aniki::Filter::Declare;
    use Scalar::Util qw/blessed/;
    use Time::Moment;

    # define inflate/deflate filters in table context.
    table author => sub {
        inflate name => sub {
            my $name = shift;
            return uc $name;
        };

        deflate name => sub {
            my $name = shift;
            return lc $name;
        };
    };
};

1;
__END__
