use 5.014002;
use File::Basename qw/dirname/;
use File::Spec;
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use MyProj::DB;
use MyProj::DB::Schema;
#use DBIx::QueryLog;

my $db = MyProj::DB->new(connect_info => ["dbi:SQLite:dbname=:memory:", "", ""]);
$db->execute($_) for split /;/, MyProj::DB::Schema->output;

my $author_id = $db->insert_and_fetch_id(author => { name => 'songmu' });

$db->insert(module => {
    name      => 'DBIx::Schema::DSL',
    author_id => $author_id,
});
$db->insert(module => {
    name      => 'Riji',
    author_id => $author_id,
});

my $module = $db->select(module => {
    name => 'Riji',
}, {
    limit => 1,
})->first;
say '$module->name:         ', $module->name;         ## Riji
say '$module->author->name: ', $module->author->name; ## SONGMU

my $author = $db->select(author => {
    name => 'songmu',
}, {
    limit    => 1,
    prefetch => [qw/modules/],
})->first;

say '$author->name:   ', $author->name;                 ## SONGMU
say 'modules[]->name: ', $_->name for $author->modules; ## DBIx::Schema::DSL, Riji
