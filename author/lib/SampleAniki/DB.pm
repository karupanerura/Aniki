use 5.014002;
package SampleAniki::DB {
    use Mouse v2.4.5;
    extends qw/Aniki/;

    __PACKAGE__->setup(
        schema => 'SampleAniki::DB::Schema',
        filter => 'SampleAniki::DB::Filter',
    );

};

1;
