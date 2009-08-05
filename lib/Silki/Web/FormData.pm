package Silki::Web::FormData;

use strict;
use warnings;

use Moose;
use MooseX::StrictConstructor;

has 'sources' =>
    ( is       => 'ro',
      isa      => 'ArrayRef[HashRef|Object]',
      required => 1,
    );

has 'suffix' =>
    ( is      => 'ro',
      isa     => 'Str',
      default => q{},
    );


sub has_sources
{
    return scalar @{ $_[0]->sources() };
}

sub param
{
    my $self  = shift;
    my $param = shift;

    if ( my $s = $self->suffix() )
    {
        $param =~ s/\Q$s\E$//;
    }

    foreach my $s ( @{ $self->sources() } )
    {
        if ( blessed $s )
        {
            return $s->$param() if $s->can($param);
        }
        else
        {
            return $s->{$param} if exists $s->{$param};
        }
    }

    return;
}


1;

__END__
