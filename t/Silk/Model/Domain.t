use strict;
use warnings;

use Test::More tests => 2;

use Silk::Model::Domain;

{
    my $domain =
        Silk::Model::Domain->new( domain_id   => 1,
                                  hostname    => 'host.example.com',
                                  _from_query => 1,
                                );
    is( $domain->base_uri(), 'http://host.example.com',
        'base_uri() for domain' );
}

{
    my $domain =
        Silk::Model::Domain->new( domain_id    => 1,
                                  hostname     => 'host.example.com',
                                  requires_ssl => 1,
                                  _from_query  => 1,
                                );
    is( $domain->base_uri(), 'https://host.example.com',
        'base_uri() for domain that requires ssl' );
}
