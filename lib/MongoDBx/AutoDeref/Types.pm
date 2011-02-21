package MongoDBx::AutoDeref::Types;

#ABSTRACT: Types specific for MongoDBx::AutoDeref

use warnings;
use strict;

use MooseX::Types -declare => [qw/ DBRef /];
use MooseX::Types::Structured(':all');
use MooseX::Types::Moose(':all');


=type DBRef
    
    Dict
    [
        '$db' => Str,
        '$ref' => Str,
        '$id' => class_type('MongoDB::OID')
    ]

For MongoDBx::AutoDeref to function, it has to operate with the codified
database reference. This type constraint checks that the hash has the necessary
fields.  One slight variation from the mongodb docs is that the $db field is
required.  This might change in the future, but it certainly doesn't hurt to be
explicit.

http://www.mongodb.org/display/DOCS/Database+References

=cut

subtype DBRef,
    as Dict
    [
        '$db' => Str,
        '$ref' => Str,
        '$id' => class_type('MongoDB::OID')
    ];

1;
__END__
