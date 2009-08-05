package Silki::AppRole::Domain;

use strict;
use warnings;

use Silki::Schema::Domain;

use Moose::Role;

has 'domain' =>
    ( is         => 'ro',
      isa        => 'Silki::Schema::Domain',
      lazy_build => 1,
    );


sub _build_domain
{
    my $self = shift;

    my $host = $self->request()->uri()->host();

    return Silki::Schema::Domain->new( web_hostname => $host )
        or die "No domain found for hostname ($host)\n";
}

1;
