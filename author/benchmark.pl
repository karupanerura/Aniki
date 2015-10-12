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
        $aniki->insert('author' => {
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
cmpthese {
    %{
        timethese 20000 => {
            dbic => sub {
                my $row = $dbic->resultset('Author')->create({
                    name => "name:".$dbic_id++,
                });
            },
            teng => sub {
                my $row = $teng->insert('author' => {
                    name => "name:".$teng_id++,
                });
            },
            'aniki(emulate)' => sub {
                my $row = $aniki->insert_and_emulate_row('author' => {
                    name => "name:".$aniki_id++,
                });
            },
        }
    },
    do {
        $aniki->dbh->do('DELETE FROM author');
        $aniki->dbh->do('DELETE FROM sqlite_sequence WHERE name = ?', undef, 'author');
        ();
    },
    %{
        timethese 20000 => {
            'aniki(fetch)' => sub {
                my $row = $aniki->insert_and_fetch_row('author' => {
                    name => "name:".$aniki_id++,
                });
            },
        }
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

say '=============== UPDATE ===============';
cmpthese timethese 20000 => {
    dbic => sub {
        my $row = $dbic->resultset('Author')->single({ id => 1 });
        $row->update({ message => 'good morning' });
    },
    'teng(row)' => sub {
        my $row = $teng->single('author' => { id => 1 });
        $row->update({ message => 'good morning' });
    },
    teng => sub {
        $teng->update('author' => { message => 'good morning' }, { id => 1 });
    },
    'aniki(row)' => sub {
        my $row = $aniki->select('author' => { id => 1 }, { limit => 1 })->first;
        $aniki->update($row => { message => 'good morning' });
    },
    aniki => sub {
        $aniki->update('author' => { message => 'good morning' }, { id => 1 });
    },
};

say '=============== DELETE ===============';
my ($dbic_delete_id, $teng_delete_id, $aniki_delete_id) = (0, 0, 0);
cmpthese {
    %{
        timethese 20000 => {
            dbic => sub {
                my $row = $dbic->resultset('Author')->single({ id => ++$dbic_delete_id });
                $row->delete;
            },
            'teng(row)' => sub {
                my $row = $teng->single('author' => { id => ++$teng_delete_id });
                $row->delete;
            },
            'aniki(row)' => sub {
                my $row = $aniki->select('author' => { id => ++$aniki_delete_id }, { limit => 1 })->first;
                $aniki->delete($row);
            },
        }
    },
    do {
        ($teng_delete_id, $aniki_delete_id) = (0, 0);
        $aniki->dbh->do('DELETE FROM author');
        $aniki->dbh->do('DELETE FROM sqlite_sequence WHERE name = ?', undef, 'author');
        $teng->dbh->do('DELETE FROM author');
        $teng->dbh->do('DELETE FROM sqlite_sequence WHERE name = ?', undef, 'author');

        for my $i (1..20000) {
            $aniki->insert('author' => { name => "name:".$i });
            $teng->fast_insert('author' => { name => "name:".$i });
        }

        ();
    },
    %{
        timethese 20000 => {
            teng => sub {
                $teng->delete('author' => { id => ++$teng_delete_id });
            },
            aniki => sub {
                $aniki->delete('author' => { id => ++$aniki_delete_id });
            },
        }
    }
};
