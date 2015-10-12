use strict;
use warnings;
use utf8;
use feature qw/say/;

use lib 'lib';
use SampleDbic::Schema;
use SampleAniki::DB;
use SampleAniki::DB::Schema;
use SampleTeng::DB;
use Benchmark qw/cmpthese timethese/;

my $aniki = SampleAniki::DB->new(connect_info => ["dbi:SQLite:dbname=:memory:", "", "", { ShowErrorStatement => 1 }]);
my $dbic = SampleDbic::Schema->connect('dbi:SQLite:dbname=:memory:');
my $teng = SampleTeng::DB->new({ connect_info => ["dbi:SQLite:dbname=:memory:", "", ""], sql_builder_args => { strict => 1 } });

$aniki->dbh->do($_) for split /;/, SampleAniki::DB::Schema->output;
$teng->dbh->do($_) for split /;/, SampleAniki::DB::Schema->output;
$dbic->storage->dbh->do($_) for split /;/, SampleAniki::DB::Schema->output;

say '=============== SCHEMA ===============';
print SampleAniki::DB::Schema->output;

say '=============== INSERT (no fetch) ===============';
my ($dbic_id, $teng_id, $aniki_id) = (0, 0, 0);
timethese 100000 => {
    aniki => sub {
        my $id = $aniki->insert_and_fetch_id('author' => {
            name => "name:".$aniki_id++,
        });
    },
};

$aniki->dbh->do('DELETE FROM author');
$aniki->dbh->do('DELETE FROM sqlite_sequence WHERE name = ?', undef, 'author');

say '=============== INSERT (fetch auto increment id only) ===============';
($dbic_id, $teng_id, $aniki_id) = (0, 0, 0);
cmpthese timethese 100000 => {
    teng => sub {
        my $id = $teng->fast_insert('author' => {
            name => "name:".$teng_id++,
        });
    },
    aniki => sub {
        my $id = $aniki->insert_and_fetch_id('author' => {
            name => "name:".$aniki_id++,
        });
    },
};

$aniki->dbh->do('DELETE FROM author');
$aniki->dbh->do('DELETE FROM sqlite_sequence WHERE name = ?', undef, 'author');
$teng->dbh->do('DELETE FROM author');
$teng->dbh->do('DELETE FROM sqlite_sequence WHERE name = ?', undef, 'author');

say '=============== INSERT ===============';
($dbic_id, $teng_id, $aniki_id) = (0, 0, 0);
cmpthese timethese 10000 => {
    dbic => sub {
        my $data = {
            name => "name:".$dbic_id++,
        };
        my $row = $dbic->resultset('Author')->create($data);
    },
    teng => sub {
        my $data = {
            name => "name:".$teng_id++,
        };
        my $row = $teng->insert('author' => $data);
    },
    aniki => sub {
        my $data = {
            name => "name:".$aniki_id++,
        };
        my $row = $aniki->insert_and_emulate_row('author' => $data);
    },
};


say '=============== SELECT ===============';
cmpthese timethese 20000 => {
    dbic => sub {
        my @rows = $dbic->resultset('Author')->search({}, { rows => 10, order_by => { -asc => 'id' } })->all;
    },
    teng => sub {
        my @rows = $teng->search('author' => {}, { limit => 10, order_by => { id => 'ASC' } })->all;
    },
    aniki => sub {
        my @rows = $aniki->select('author' => {}, { limit => 10, order_by => { id => 'ASC' } })->all;
    },
};
