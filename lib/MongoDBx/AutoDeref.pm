package MongoDBx::AutoDeref;
use warnings;
use strict;
use feature qw/state say/;
use Class::Load('load_class');
use MongoDBx::AutoDeref::LookMeUp;

sub import
{
    my ($class) = @_;

    load_class('MongoDB');
    my $cur = 'MongoDB::Cursor'->meta();
    $cur->make_mutable();
    $cur->add_around_method_modifier(
        'next',
        sub
        {
            my ($orig, $self, @args) = @_;
            state $lookmeup = MongoDBx::AutoDeref::LookMeUp->new(
                mongo_connection => $self->_connection
            );

            my $ret = $self->$orig(@args);
            if(defined($ret))
            {
                $lookmeup->sieve($ret);
            }

            return $ret;
        }
    );
    $cur->make_immutable(inline_destructor => 0);
}

1;
