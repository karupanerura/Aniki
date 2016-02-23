package Aniki::Schema;
use 5.014002;

use namespace::sweep;
use Mouse v2.4.5;

use SQL::Translator::Schema::Constants;
use Carp qw/croak/;
use Aniki::Schema::Table;

has schema_class => (
    is       => 'ro',
    required => 1,
);

has context => (
    is      => 'ro',
    default => sub { shift->schema_class->context }
);

has _table_cache => (
    is      => 'ro',
    default => sub {
        my $self = shift;
        return {
            map { $_->name => Aniki::Schema::Table->new($_, $self) } $self->context->schema->get_tables()
        };
    },
);

sub BUILD {
    my $self = shift;

    # for cache
    for my $table ($self->get_tables) {
        for my $relationship ($table->get_relationships->all) {
            $relationship->get_inverse_relationships();
        }
    }
}

sub get_table {
    my ($self, $table_name) = @_;
    return unless exists $self->_table_cache->{$table_name};
    return $self->_table_cache->{$table_name};
}

sub get_tables {
    my $self = shift;
    return values %{ $self->_table_cache };
}

sub has_many {
    my ($self, $table_name, $fields) = @_;
    my $table = $self->context->schema->get_table($table_name);
    return !!1 unless defined $table;

    my %field = map { $_ => 1 } @$fields;
    for my $unique (grep { $_->type eq UNIQUE || $_->type eq PRIMARY_KEY } $table->get_constraints) {
        my @field_names    = $unique->field_names;
        my @related_fields = grep { $field{$_} } @field_names;
        return !!0 if @field_names == @related_fields;
    }
    for my $index (grep { $_->type eq UNIQUE } $table->get_indices) {
        my @field_names    = $index->fields;
        my @related_fields = grep { $field{$_} } @field_names;
        return !!0 if @field_names == @related_fields;
    }
    return !!1;
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    my $method = $AUTOLOAD =~ s/^.*://r;
    if ($self->context->schema->can($method)) {
        return $self->context->schema->$method(@_);
    }

    my $class = ref $self;
    croak qq{Can't locate object method "$method" via package "$class"};
}

__PACKAGE__->meta->make_immutable();
__END__
