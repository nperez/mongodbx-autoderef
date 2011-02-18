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

has mongo_connection =>
(
    is => 'ro',
    isa => 'MongoDB::Connection',
    required => 1,
);

has visitor =>
(
    is => 'ro',
    isa => 'Data::Visitor::Callback',
    lazy => 1,
    builder => '_build_visitor',
    handles => { 'sieve' => 'visit' },
);

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
