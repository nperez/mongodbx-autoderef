package MongoDBx::AutoDeref::LookMeUp;

#ABSTRACT: Provides the sieve that replaces DBRefs with deferred scalars.

use Moose;
use namespace::autoclean;

use Scalar::Util('weaken');
use MooseX::Types::Structured(':all');
use MooseX::Types::Moose(':all');
use Data::Visitor::Callback;
use Scalar::Defer;
use MongoDBx::AutoDeref::Types(':all');
use Perl6::Junction('any');

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

=attribute_public visitor

    is: ro, isa: Data::Visitor::Callback
    lazy: 1, builder => _build_visitor
    handles: sieve => visit

In order to find the DBRefs within the returned document, Data::Visitor is used
to traverse the structure. This attribute is built using the provided builder
with the default L</hash_visit_action> setup to build the lazy look up.

=cut

=method_public sieve

    (HashRef)

This method takes the returned document from MongoDB and traverses it to replace
DBRefs with defered lookups of the actual document. It does this IN PLACE on the
document.

=cut

has visitor =>
(
    is => 'ro',
    isa => 'Data::Visitor::Callback',
    lazy => 1,
    builder => '_build_visitor',
    handles => { 'sieve' => 'visit' },
);

=attribute_public hash_visit_action

    is: ro, isa: CodeRef
    builder: _build_hash_visit_action
    lazy: 1

This attribute holds the code reference that will be executed upon each hash
found within the data structure returned from MongoDB. By default, the coderef
built using the builder method uses L<Scalar::Defer/lazy> to defer lookup of the
referenced document until access time. 

=cut

has hash_visit_action =>
(
    is => 'ro',
    isa => CodeRef,
    builder => '_build_hash_visit_action',
    lazy => 1,
);

sub _build_hash_visit_action
{
    my ($self) = @_;
    weaken($self);
    sub
    {
        my ($visitor, $data) = @_;
        return unless is_DBRef($data);

        my %hash = %$data;
        $_ = lazy
        {
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

            $self->sieve($doc);
            return $doc;

        };
    }
}

sub _build_visitor
{
    my ($self) = @_;
    return Data::Visitor::Callback->new
    (
        hash => $self->hash_visit_action,
        ignore_return_values => 1,
    );
}

1;
__END__

=head1 DESCRIPTION

This module provides the guts for L<MongoDBx::AutoDeref>. It modifies documents
in place to replace DBRefs with defered lookups of the actual document. 
