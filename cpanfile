requires 'DBIx::Handler';
requires 'DBIx::Sunny';
requires 'DBIx::Schema::DSL';
requires 'Hash::Util::FieldHash';
requires 'Lingua::EN::Inflect';
requires 'List::MoreUtils';
requires 'List::UtilsBy';
requires 'Module::Load';
requires 'Mouse';
requires 'SQL::Maker';
requires 'SQL::Maker::SQLType';
requires 'SQL::Translator::Schema::Constants';
requires 'Scalar::Util';
requires 'String::CamelCase';
requires 'Try::Tiny';
requires 'namespace::sweep';
requires 'parent';
requires 'perl', '5.014002';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
};

on test => sub {
    requires 'Test::More', '0.98';
};
