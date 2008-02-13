use strict;
use warnings;

use Test::More tests => 5;

use DateTime;
use DateTime::Format::Pg;
use Silk::Model::Domain;
use Silk::Model::User;
use Silk::Model::Wiki;

use lib 't/lib';
use Silk::Test qw( mock_dbh );


{
    my $domain =
        Silk::Model::Domain->new( domain_id    => 1,
                                  hostname     => 'host.example.com',
                                  path_prefix  => '',
                                  requires_ssl => 0,
                                  _from_query  => 1,
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
        Silk::Model::Domain->new( domain_id    => 1,
                                  hostname     => 'host.example.com',
                                  path_prefix  => '/silk',
                                  requires_ssl => 0,
                                  _from_query  => 1,
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

my $dbh = mock_dbh();

{
    $dbh->{mock_start_insert_id} = [ q{"Wiki"}, 42 ];
    $dbh->{mock_start_insert_id} = [ q{"Page"}, 3 ];

    $dbh->{mock_add_resultset} = [];

    $dbh->{mock_add_resultset} =
        [ [ qw( domain_id locale_code email_addresses_are_hidden
                short_name title user_id ) ],
          [ qw( 1 en_US 0 some-wiki ), 'Some Wiki', 99 ],
        ];

    $dbh->{mock_add_resultset} = [];

    $dbh->{mock_add_resultset} =
        [ [ qw( is_archived user_id wiki_id ) ],
          [ 0, 99, 42 ],
        ];

    $dbh->{mock_add_resultset} = [];

    my $now = DateTime::Format::Pg->format_timestamp( DateTime->now( time_zone => 'UTC' ) );

    $dbh->{mock_add_resultset} =
        [ [ qw( content creation_datetime is_restoration_of_revision_number
                title user_id ) ],
          [ 'Welcome to Some Wiki', $now, undef,
            'Front Page', 99 ],
        ];

    my $wiki =
        Silk::Model::Wiki->insert( title      => 'Some Wiki',
                                   short_name => 'some-wiki',
                                   domain_id  => 1,
                                   user_id    => 99,
                                 );


    my @inserts =
        map { $_->bound_params() }
        grep { $_->statement() =~ /^INSERT/ }
        @{ $dbh->{mock_all_history} };

    is_deeply( $inserts[0],
               [ 1, 'some-wiki', 'Some Wiki', 99 ],
               'Wiki data was inserted as expected' );

    is_deeply( $inserts[1],
               [ 99, 42 ],
               'Creating a wiki also creates a front page' );

    is_deeply( $inserts[2],
               [ 'Welcome to Some Wiki', 3, 1, 'Front Page', 99 ],
               'Creating a wiki also creates a front page (page revision)' );
}
