requires 'B::Hooks::EndOfScope';
requires 'Class::Inspector';
requires 'DBI';
requires 'DBIx::Handler', '0.12';
requires 'DBIx::Schema::DSL';
requires 'Data::Page::NoTotalEntries';
requires 'Data::Section::Simple';
requires 'File::Path';
requires 'Getopt::Long';
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
requires 'namespace::autoclean';
requires 'parent';
requires 'perl', '5.014002';

recommends 'SQL::Maker::Plugin::JoinSelect';
recommends 'Data::WeightedRoundRobin';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
};

on test => sub {
    requires 'DBD::SQLite';
    requires 'List::Util';
    requires 'Mouse::Util';
    requires 'Test::Builder';
    requires 'Test::Builder::Module';
    requires 'Test::More', '0.98';
    requires 'Test::Requires';
    requires 'feature';
    recommends 'DBD::mysql';
    recommends 'Test::mysqld';
    recommends 'DBD::Pg';
    recommends 'Test::postgresql';
};

on develop => sub {
    requires 'DBIx::Class::Core';
    requires 'DBIx::Class::Schema';
    requires 'Teng';
    requires 'Teng::Schema::Declare';
    requires 'Time::Moment';
};
