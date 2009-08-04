use strict;
use warnings;

use Test::More tests => 3;

use Silki::Schema::Domain;

{
    my $domain =
        Silki::Schema::Domain->new( domain_id    => 1,
                                    hostname     => 'host.example.com',
                                    requires_ssl => 0,
                                    path_prefix  => '',
                                    _from_query  => 1,
                                  );
    is( $domain->base_uri(), 'http://host.example.com',
        'base_uri() for domain' );
}

{
    my $domain =
        Silki::Schema::Domain->new( domain_id    => 1,
                                    hostname     => 'host.example.com',
                                    path_prefix  => '',
                                    requires_ssl => 1,
                                    _from_query  => 1,
                                  );
    is( $domain->base_uri(), 'https://host.example.com',
        'base_uri() for domain that requires ssl' );
}

{
    my $domain =
        Silki::Schema::Domain->new( domain_id    => 1,
                                    hostname     => 'host.example.com',
                                    requires_ssl => 0,
                                    path_prefix  => '/silk',
                                    _from_query  => 1,
                                  );
    is( $domain->base_uri(), 'http://host.example.com/silk',
        'base_uri() for domain with a path prefix' );
}
