[![Build Status](https://travis-ci.org/karupanerura/Aniki.svg?branch=master)](https://travis-ci.org/karupanerura/Aniki)
# NAME

Aniki - The ORM as our great brother.

# SYNOPSIS

    use 5.014002;
    package MyProj::DB::Schema {
        use DBIx::Schema::DSL;

        create_table 'module' => columns {
            integer 'id', primary_key, auto_increment;
            varchar 'name';
            integer 'author_id';

            add_index 'author_id_idx' => ['author_id'];

            belongs_to 'author';
        };

        create_table 'author' => columns {
            integer 'id', primary_key, auto_increment;
            varchar 'name', unique;
        };
    };

    package MyProj::DB::Filter {
        use Aniki::Filter::Declare;
        use Scalar::Util qw/blessed/;
        use Time::Moment;

        # define inflate/deflate filters in table context.
        table author => sub {
            inflate name => sub {
                my $name = shift;
                return uc $name;
            };

            deflate name => sub {
                my $name = shift;
                return lc $name;
            };
        };

        inflate qr/_at$/ => sub {
            my $datetime = shift;
            $datetime =~ tr/ /T/;
            $datetime .= 'Z';
            return Time::Moment->from_string($datetime);
        };

        deflate qr/_at$/ => sub {
            my $datetime = shift;
            return $datetime->at_utc->strftime('%F %T') if blessed $datetime and $datetime->isa('Time::Moment');
            return $datetime;
        };
    };

    package MyProj::DB {
        use Mouse v2.4.5;
        extends qw/Aniki/;

        __PACKAGE__->setup(
            schema => 'MyProj::DB::Schema',
            filter => 'MyProj::DB::Filter',
            row    => 'MyProj::DB::Row',
        );
    };

    package main {
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
    };

    1;

# DESCRIPTION

Aniki is ORM.
Lite, but powerful.

## FEATURES

- Small & Simple

    You can read codes easily.

- Object mapping

    Inflates rows to [Aniki::Result::Collection](https://metacpan.org/pod/Aniki::Result::Collection) object.
    And inflates row to [Aniki::Row](https://metacpan.org/pod/Aniki::Row) object.

    You can change result class, also we can change row class.
    Aniki dispatches result/row class by table. (e.g. `foo` table to `MyDB::Row::Foo`)

- Raw SQL support

    Supports to execute raw `SELECT` SQL and fetch rows of result.
    Of course, Aniki can inflate to result/row also.

- Query builder

    Aniki includes query builder powered by [SQL::Maker](https://metacpan.org/pod/SQL::Maker).
    [SQL::Maker](https://metacpan.org/pod/SQL::Maker) is fast and secure SQL builder.

- Fork safe & Transaction support

    Aniki includes [DBI](https://metacpan.org/pod/DBI) handler powered by [DBIx::Handler](https://metacpan.org/pod/DBIx::Handler).

- Error handling

    Easy to handle execution errors by `handle_error` method.
    You can override it.

- Extendable

    You can extend Aniki by [Mouse::Role](https://metacpan.org/pod/Mouse::Role).
    Aniki provides some default plugins as [Mouse::Role](https://metacpan.org/pod/Mouse::Role).

## RELATIONSHIP

Aniki supports relationship.
Extracts relationship from schema class.

Example:

    use 5.014002;
    package MyProj::DB::Schema {
        use DBIx::Schema::DSL;

        create_table 'module' => columns {
            integer 'id', primary_key, auto_increment;
            varchar 'name';
            integer 'author_id';

            add_index 'author_id_idx' => ['author_id'];

            belongs_to 'author';
        };

        create_table 'author' => columns {
            integer 'id', primary_key, auto_increment;
            varchar 'name', unique;
        };
    };

A `author` has many `modules`.
So you can access `author` row object to `modules`.

    my $author = $db->select(author => { name => 'songmu' })->first;
    say 'modules[]->name: ', $_->name for $author->modules; ## DBIx::Schema::DSL, Riji

Also `module` has a `author`.
So you can access `module` row object to `author` also.

    my $module = $db->select(module => { name => 'Riji' })->first;
    say "Riji's author is ", $module->author->name; ## SONGMU

And you can pre-fetch related rows.

    my @modules = $db->select(module => {}, { prefetch => [qw/author/] });
    say $_->name, "'s author is ", $_->author->name for @modules;

# SETUP

Install Aniki from CPAN:

    cpanm Aniki

And run `install-aniki` command.

    install-aniki --lib=./lib MyApp::DB

`install-aniki` creates skeleton modules.

# METHODS

## CLASS METHODS

### `setup(%args)`

Initialize and customize Aniki class.
`schema` is required. Others are optional.

#### Arguments

- schema : ClassName
=item handler : ClassName
=item filter : ClassName
=item row : ClassName
=item result : ClassName
=item query\_builder : ClassName

### `use_prepare_cached`

If this method returns true value, Aniki uses `preare_cached`.
This method returns true value default.
So you don't need to use `preare_cached`, override it and return false value.

### `use_strict_query_builder`

If this method returns true value, Aniki enables [SQL::Maker](https://metacpan.org/pod/SQL::Maker)'s strict mode.
This method returns true value default.
So you need to disable [SQL::Maker](https://metacpan.org/pod/SQL::Maker)'s strict mode, override it and return false value.

SEE ALSO: [The JSON SQL Injection Vulnerability](http://blog.kazuhooku.com/2014/07/the-json-sql-injection-vulnerability.html)

### `preload_all_row_classes`

Preload all row classes.

### `preload_all_result_classes`

Preload all result classes.

### `guess_result_class($table_name) : ClassName`

Guesses result class by table name.

### `guess_row_class($table_name) : ClassName`

Guesses row class by table name.

### `new(%args) : Aniki`

Create instance of Aniki.

#### Arguments

- `handler : Aniki::Handler`

    Instance of Aniki::Hanlder.
    If this argument is given, not required to give `connect_info` for arguments.

- `connect_info : ArrayRef`

    Auguments for [DBI](https://metacpan.org/pod/DBI)'s connect method.

- on\_connect\_do : CodeRef|ArrayRef\[Str\]|Str
=item on\_disconnect\_do : CodeRef|ArrayRef\[Str\]|Str

    Execute SQL or CodeRef when connected/disconnected.

- `suppress_row_objects : Bool`

    If this option is true, no create row objects.
    Aniki's methods returns hash reference instead of row object.

- `suppress_result_objects : Bool`

    If this option is true, no create result objects.
    Aniki's methods returns array reference instead of result object.

## INSTANCE METHODS

### `select($table_name, \%where, \%opt)`

Execute `SELECT` query by generated SQL, and returns result object.

    my $result = $db->select(foo => { id => 1 }, { limit => 1 });
    # stmt: SELECT FROM foo WHERE id = ? LIMIT 1
    # bind: [1]

#### Options

There are the options of `SELECT` query.
See also [SQL::Maker](https://metacpan.org/pod/SQL::Maker#opt).

And you can use there options:

- `suppress_row_objects : Bool`

    If this option is true, no create row objects.
    This methods returns hash reference instead of row object.

- `suppress_result_objects : Bool`

    If this option is true, no create result objects.
    This method returns array reference instead of result object.

- `columns : ArrayRef[Str]`

    List for retrieving columns from database.

- `prefetch : ArrayRef|HashRef`

    Pre-fetch specified related rows.
    See also ["RELATIONSHIP"](#relationship) section.

### `select_named($sql, \%bind, \%opt)`

### `select_by_sql($sql, \@bind, \%opt)`

Execute `SELECT` query by specified SQL, and returns result object.

    my $result = $db->select_by_sql('SELECT FROM foo WHERE id = ? LIMIT 1', [1]);
    # stmt: SELECT FROM foo WHERE id = ? LIMIT 1
    # bind: [1]

#### Options

You can use there options:

- `table_name: Str`

    This is table name using row/result class guessing.

- `columns: ArrayRef[Str]`

    List for retrieving columns from database.

- `prefetch: ArrayRef|HashRef`

    Pre-fetch specified related rows.
    See also ["RELATIONSHIP"](#relationship) section.

### `insert($table_name, \%values, \%opt)`

Execute `INSERT INTO` query.

    $db->insert(foo => { bar => 1 });
    # stmt: INSERT INTO foo (bar) VALUES (?)
    # bind: [1]

### `insert_and_fetch_id($table_name, \%values, \%opt)`

Execute `INSERT INTO` query, and returns `last_insert_id`.

    my $id = $db->insert_and_fetch_id(foo => { bar => 1 });
    # stmt: INSERT INTO foo (bar) VALUES (?)
    # bind: [1]

### `insert_and_fetch_row($table_name, \%values, \%opt)`

Execute `INSERT INTO` query, and `SELECT` it, and returns row object.

    my $row = $db->insert_and_fetch_row(foo => { bar => 1 });
    # stmt: INSERT INTO foo (bar) VALUES (?)
    # bind: [1]

### `insert_and_emulate_row($table_name, \%values, \%opt)`

Execute `INSERT INTO` query, and returns row object created by `$row` and schema definition.

    my $row = $db->insert_and_fetch_row(foo => { bar => 1 });
    # stmt: INSERT INTO foo (bar) VALUES (?)
    # bind: [1]

This method is faster than `insert_and_fetch_row`.

#### WARNING

If you use SQL `TRIGGER` or dynamic default value, this method don't return the correct value, maybe.
In this case, you should use `insert_and_fetch_row` instead of this method.

### `insert_on_duplicate($table_name, \%insert, \%update)`

Execute `INSERT ... ON DUPLICATE KEY UPDATE` query for MySQL.

    my $row = $db->insert_on_duplicate(foo => { bar => 1 }, { bar => \'VALUE(bar) + 1' });
    # stmt: INSERT INTO foo (bar) VALUES (?) ON DUPLICATE KEY UPDATE bar = VALUE(bar) + 1
    # bind: [1]

SEE ALSO: [INSERT ... ON DUPLICATE KEY UPDATE Syntax](https://dev.mysql.com/doc/refman/5.6/en/insert-on-duplicate.html)

### `insert_multi($table_name, \@values, \%opts)`

Execute `INSERT INTO ... (...) VALUES (...), (...), ...` query for MySQL.
Insert multiple rows at once.

    my $row = $db->insert_multi(foo => [{ bar => 1 }, { bar => 2 }, { bar => 3 }]);
    # stmt: INSERT INTO foo (bar) VALUES (?),(?),(?)
    # bind: [1, 2, 3]

SEE ALSO: [INSERT Syntax](https://dev.mysql.com/doc/refman/5.6/en/insert.html)

### `update($table_name, \%set, \%where)`

Execute `UPDATE` query, and returns changed rows count.

    my $count = $db->update(foo => { bar => 2 }, { id => 1 });
    # stmt: UPDATE foo SET bar = ? WHERE id = ?
    # bind: [2, 1]

### `update($row, \%set)`

Execute `UPDATE` query, and returns changed rows count.

    my $row = $db->select(foo => { id => 1 }, { limit => 1 })->first;
    my $count = $db->update($row => { bar => 2 });
    # stmt: UPDATE foo SET bar = ? WHERE id = ?
    # bind: [2, 1]

### `delete($table_name, \%where)`

Execute `DELETE` query, and returns changed rows count.

    my $count = $db->delete(foo => { id => 1 });
    # stmt: DELETE FROM foo WHERE id = ?
    # bind: [1]

### `delete($row)`

Execute `DELETE` query, and returns changed rows count.

    my $row = $db->select(foo => { id => 1 }, { limit => 1 })->first;
    my $count = $db->delete($row);
    # stmt: DELETE foo WHERE id = ?
    # bind: [1]

## ACCESSORS

- `schema : Aniki::Schema`
- `filter : Aniki::Filter`
- `query_builder : Aniki::QueryBuilder`
- `root_row_class : Aniki::Row`
- `root_result_class : Aniki::Result`
- `connect_info : ArrayRef`
- `on_connect_do : CodeRef|ArrayRef[Str]|Str`
- `on_disconnect_do : CodeRef|ArrayRef[Str]|Str`
- `suppress_row_objects : Bool`
- `suppress_result_objects : Bool`
- `dbh : DBI::db`
- `handler : Aniki::Handler`
- `txn_manager : DBIx::TransactionManager`

# CONTRIBUTE

I need to support documentation and reviewing my english.
This module is developed on [Github](http://github.com/karupanerura/Aniki).

# LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

karupanerura <karupa@cpan.org>
