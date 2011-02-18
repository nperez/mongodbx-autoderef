package MongoDBx::AutoDeref::Types;
use warnings;
use strict;

use MooseX::Types -declare => [qw/ DBRef /];
use MooseX::Types::Structured(':all');
use MooseX::Types::Moose(':all');

subtype DBRef,
    as Dict
    [
        '$db' => Str,
        '$ref' => Str,
        '$id' => class_type('MongoDB::OID')
    ];

1;
__END__
