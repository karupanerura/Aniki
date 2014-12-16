requires 'DBIx::Handler';
requires 'DBIx::Sunny';
requires 'Lingua::EN::Inflect';
requires 'Module::Load';
requires 'Moo';
requires 'SQL::Maker';
requires 'SQL::Maker::SQLType';
requires 'SQL::Translator::Schema::Constants';
requires 'Scalar::Util';
requires 'String::CamelCase';
requires 'Try::Tiny';
requires 'Type::Tiny';
requires 'namespace::sweep';
requires 'parent';
requires 'perl', '5.014002';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
};

on test => sub {
    requires 'Test::More', '0.98';
};
