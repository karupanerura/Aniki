use 5.014002;
package Aniki::Schema::Relation {
    use namespace::sweep;
    use Mouse;

    has name => (
        is       => 'ro',
        required => 1,
    );

    has table_name => (
        is       => 'ro',
        required => 1,
    );

    has has_many => (
        is       => 'ro',
        required => 1,
    );

    has src => (
        is       => 'ro',
        required => 1,
    );

    has dest => (
        is       => 'ro',
        required => 1,
    );
}

1;
__END__
