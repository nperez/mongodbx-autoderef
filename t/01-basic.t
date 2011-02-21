use Test::More;
use warnings;
use strict;
use MongoDB;
use MongoDBx::AutoDeref;
use Digest::SHA1('sha1_hex');

my $db_name = sha1_hex(time().rand().'mtfnpy'.$$);

my $con = MongoDB::Connection->new();
my $db = $con->get_database($db_name);
$db->drop();
my $col = $db->get_collection('bar');
my $doc1 = { foo => 'bar' };
my $doc2 = { bar => 'baz' };
my $doc3 = { baz => 'foo' };

my $id1 = $col->insert($doc1);
$doc2->{source} = { '$db' => $db_name, '$ref' => 'bar', '$id' => $id1 };
my $id2 = $col->insert($doc2);
$doc3->{source} = { '$db' => $db_name, '$ref' => 'bar', '$id' => $id2 };
my $id3 = $col->insert($doc3);
$doc1->{source} = { '$db' => $db_name, '$ref' => 'bar', '$id' => $id3 };
$col->update({ _id => $id1}, $doc1);

my $fetch = $col->find_one({_id => $id3});

is($fetch->{baz}, 'foo', 'doc3 element matches');
is($fetch->{source}->{bar}, 'baz', 'doc2 element matches');
is($fetch->{source}->{source}->{foo}, 'bar', 'doc1 element matches');
is($fetch->{source}->{source}->{source}->{baz}, 'foo',
    'loop through the circular structure');

$db->drop();
done_testing();
