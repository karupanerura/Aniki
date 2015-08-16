requires 'B::Hooks::EndOfScope';
requires 'DBIx::Handler';
requires 'DBIx::Schema::DSL';
requires 'DBIx::Sunny';
requires 'Data::Page::NoTotalEntries';
requires 'Hash::Util::FieldHash';
requires 'Lingua::EN::Inflect';
requires 'List::MoreUtils';
requires 'List::UtilsBy';
requires 'Module::Load';
requires 'Mouse', 'v2.4.5';
requires 'Mouse::Role';
requires 'Mouse::Util::TypeConstraints';
requires 'SQL::Maker', '1.19';
requires 'SQL::Maker::SQLType';
requires 'SQL::NamedPlaceholder';
requires 'SQL::QueryMaker';
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
    requires 'DBD::SQLite';
    requires 'Mouse::Util';
    requires 'Test::Builder::Module';
    requires 'Test::More', '0.98';
    requires 'feature';
};
