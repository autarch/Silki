package Silki::AppRole::Domain;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Schema::Domain;

use Moose::Role;

has 'domain' => (
    is      => 'ro',
    isa     => 'Silki::Schema::Domain',
    lazy    => 1,
    builder => '_build_domain',
);

sub _build_domain {
    my $self = shift;

    my $host = $self->request()->uri()->host();

    my $domain = Silki::Schema::Domain->new( web_hostname => $host )
        or die "No domain found for hostname ($host)\n";

    return $domain;
}

1;
