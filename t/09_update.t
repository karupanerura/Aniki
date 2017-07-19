use strict;
use warnings;
use utf8;

use Test::More;

use File::Spec;
use lib File::Spec->catfile('t', 'lib');
use t::Util;

run_on_database {
    db->insert(author => { name => 'MOZNION' });
    db->update(author => { name => 'MOZNION2' }, { name => 'MOZNION' });

    my $rows = db->select(author => {});
    isa_ok $rows, 'Aniki::Result::Collection';
    is $rows->count, 1;
    is $rows->first->name, 'MOZNION2', 'updated';

    my $row = $rows->first;
    my $cnt = db->update($row => { name => 'MOZNION' });
    is $row->name, 'MOZNION2', 'old value';
    is $cnt, 1, 'a row is changed';

    my $new_row = $row->refetch;
    isnt $new_row, $row;
    is $new_row->name, 'MOZNION', 'new value';

    my ($line, $file);
    eval { db->update($row) }; ($line, $file) = (__LINE__, __FILE__);
    like $@, qr/^\Q(Aniki#update) `set` is required for update ("SET" parameter) at $file line $line/, 'croak with no set parameters';

    eval { db->update($row => {}) }; ($line, $file) = (__LINE__, __FILE__);
    like $@, qr/^\Q(Aniki#update) `set` is required for update ("SET" parameter) at $file line $line/, 'croak with empty set parameters';

    eval { db->update(author => { name => 'MOZNION3' }, 'id = 1') }; ($line, $file) = (__LINE__, __FILE__);
    like $@, qr/^\Q(Aniki#update) `where` condition must be a reference at $file line $line/, 'croak with invalid where parameters';
};

done_testing();
