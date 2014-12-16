use 5.014002;
use File::Basename qw/dirname/;
use File::Spec;
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use MyProj::DB;

my $db = MyProj::DB->new("dbi:SQLite:dbname=:memory:", "", "");
$db->execute("CREATE TABLE $_") for $db->schema->get_tables;
my $author_id = $db->insert_and_fetch_id(author => { name => 'songmu' });

$db->insert(module => {
    name      => 'DBIx::Schema::DSL',
    author_id => $author_id,
});
$db->insert(module => {
    name      => 'Riji',
    author_id => $author_id,
});

my ($module) = $db->select(module => {
    name => 'Riji',
}, {
    limit => 1,
});
$module->name;         ## Riji
$module->author->name; ## SONGMU

my ($author) = $db->select(author => {
    name => 'songmu',
}, {
    limit => 1,
    relay => [qw/module/],
});

$author->name;                 ## SONGMU
$_->name for $author->modules; ## DBIx::Schema::DSL, Riji
