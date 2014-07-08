use 5.014002;
package Aniki 0.01 {
    # TBD #
}
1;
__END__

=encoding utf-8

=head1 NAME

Aniki - The ORM as our great brother.

=head1 SYNOPSIS

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
            has_many 'module';
        };
    };

    package MyProj::DB {
        use parent qw/Aniki/;
        __PACKAGE__->load_schema('MyProj::DB::Schema');
    };

    package main {
        my $db = MyProj::DB->new(...);
        $db->schema->add_table(name => $_) for $db->schema->get_tables;
        $db->insert(author => { name => 'SONGMU' });

        my $author_id = $db->last_insert_id;
        $db->insert(module => {
            name      => 'DBIx::Schema::DSL',
            author_id => $author_id,
        });
        $db->insert(module => {
            name      => 'Riji',
            author_id => $author_id,
        });

        my $module_id = $db->last_insert_id;
        my ($module) = $db->select(module => {
            id => $module_id,
        }, {
            limit => 1,
        });
        $module->name;         ## Riji
        $module->author->name; ## SONGMU

        my ($author) = $db->select(author => {
            name => 'SONGMU',
        }, {
            limit => 1,
            relay => [qw/module/],
        });
        $author->name;                 ## SONGMU
        $_->name for $author->modules; ## DBIx::Schema::DSL, Riji
    };

    1;

=head1 DESCRIPTION

Aniki is ...

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut

