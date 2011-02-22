package MongoDBx::AutoDeref::DBRef;

#ABSTRACT: DBRef representation in Perl

use Moose;
use namespace::autoclean;
use MooseX::Types::Moose(':all');

=attribute_public mongo_connection

    is: ro, isa: MongoDB::Connection, required: 1

In order to defer fetching the referenced document, a connection object needs to
be accessible. This is required for construction of the object.

=cut

has mongo_connection =>
(
    is => 'ro',
    isa => 'MongoDB::Connection',
    required => 1,
);

=attribute_public $id

    is: ro, isa: MongoDB::OID, reader: id, required: 1

This is the OID of the object.
    
=cut

has '$id' =>
(
    is => 'ro',
    isa => 'MongoDB::OID',
    reader => 'id',
    required => 1,
);

=attribute_public $ref

    is: ro, isa: Str, reader: ref, required: 1

This is the collection in which this item resides.

=cut

has '$ref' =>
(
    is => 'ro',
    isa => Str,
    reader => 'ref',
    required => 1,
);

=attribute_public $db

    is: ro, isa: Str, reader: db, required: 1

This is the database in which this item resides.

=cut

has '$db' =>
(
    is => 'ro',
    isa => Str,
    reader => 'db',
    required => 1,
);

=attribute_public lookmeup

    is: ro, isa: MongoDBx::AutoDeref::LookMeUp, weak_ref: 1, required: 1

When fetching referenced documents, those documents may in turn reference other
documents. By providing a LookMeUp object, those other references can also be
travered as DBRefs.

=cut

has lookmeup =>
(
    is => 'ro',
    isa => 'MongoDBx::AutoDeref::LookMeUp',
    required => 1,
    weak_ref => 1,
);

=method_public revert

This method returns a hash reference in the DBRef format suitable for MongoDB
serialization.

=cut

sub revert
{
    my ($self) = @_;
    return +{ '$db' => $self->db, '$ref' => $self->ref, '$id' => $self->id };
}

=method_public fetch

fetch takes the information contained in the L</$db>, L</$ref>, L</$id>
attributes and applies them via the L</mongo_connection> to retrieve the
document that is referenced.

=cut

sub fetch
{
    my ($self) = @_;
    my %hash = %{$self->revert()};
    my @dbs = $self->mongo_connection->database_names();
    die "Database '$hash{'$db'}' doesn't exist"
        unless (scalar(@dbs) > 0 || any(@dbs) eq $hash{'$db'});

    my $db = $self->mongo_connection->get_database($hash{'$db'});
    my @cols = $db->collection_names;

    die "Collection '$hash{'$ref'}' doesn't exist in $hash{'$db'}"
        unless (scalar(@cols) > 0 || any(@cols) eq $hash{'$ref'});

    my $collection = $db->get_collection($hash{'$ref'});

    my $doc = $collection->find_one
    ({
        _id => $hash{'$id'}
    }) or die "Unable to find document with _id: '$hash{'$id'}'";

    $self->lookmeup->sieve($doc);
    return $doc;
}

__PACKAGE__->meta->make_immutable();
1;
__END__

=head1 DESCRIPTION

MongoDBx::AutoDeref::DBRef is the Perl space representation of Mongo database
references. These ideally shouldn't be constructed manually, but instead should
be constructed by the internal L<MongoDBx::AutoDeref::LookMeUp> class. 
