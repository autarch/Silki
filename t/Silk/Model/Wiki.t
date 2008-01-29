use strict;
use warnings;

use Test::More tests => 2;

use Silk::Model::Wiki;

{
    my $domain =
        Silk::Model::Domain->new( domain_id   => 1,
                                  hostname    => 'host.example.com',
                                  _from_query => 1,
                                );

    no warnings 'redefine';
    local *Silk::Model::Wiki::domain = sub { return $domain };

    my $wiki =
        Silk::Model::Wiki->new( wiki_id    => 1,
                                title      => 'Some Wiki',
                                short_name => 'some-wiki',
                                _from_query => 1,
                              );

    is( $wiki->base_uri(), 'http://host.example.com/wiki/some-wiki',
        'base_uri() for wiki' );
}

{
    my $domain =
        Silk::Model::Domain->new( domain_id   => 1,
                                  hostname    => 'host.example.com',
                                  path_prefix => '/silk',
                                  _from_query => 1,
                                );

    no warnings 'redefine';
    local *Silk::Model::Wiki::domain = sub { return $domain };

    my $wiki =
        Silk::Model::Wiki->new( wiki_id    => 1,
                                title      => 'Some Wiki',
                                short_name => 'some-wiki',
                                _from_query => 1,
                              );

    is( $wiki->base_uri(), 'http://host.example.com/silk/wiki/some-wiki',
        'base_uri() for wiki in domain with path prefix' );
}
