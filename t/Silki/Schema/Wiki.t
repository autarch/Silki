use strict;
use warnings;

use Test::More tests => 5;

use DateTime;
use DateTime::Format::Pg;
use Silki::Schema::Domain;
use Silki::Schema::User;
use Silki::Schema::Wiki;

use lib 't/lib';
use Silki::Test qw( mock_dbh );


{
    my $domain =
        Silki::Schema::Domain->new( domain_id    => 1,
                                    hostname     => 'host.example.com',
                                    path_prefix  => '',
                                    requires_ssl => 0,
                                    _from_query  => 1,
                                  );

    no warnings 'redefine';
    local *Silki::Schema::Wiki::domain = sub { return $domain };

    my $wiki =
        Silki::Schema::Wiki->new( wiki_id    => 1,
                                  title      => 'Some Wiki',
                                  short_name => 'some-wiki',
                                  _from_query => 1,
                                );

    is( $wiki->base_uri(), 'http://host.example.com/wiki/1',
        'base_uri() for wiki' );
}

{
    my $domain =
        Silki::Schema::Domain->new( domain_id    => 1,
                                    hostname     => 'host.example.com',
                                    path_prefix  => '/silk',
                                    requires_ssl => 0,
                                    _from_query  => 1,
                                  );

    no warnings 'redefine';
    local *Silki::Schema::Wiki::domain = sub { return $domain };

    my $wiki =
        Silki::Schema::Wiki->new( wiki_id    => 1,
                                  title      => 'Some Wiki',
                                  short_name => 'some-wiki',
                                  _from_query => 1,
                                );

    is( $wiki->base_uri(), 'http://host.example.com/silk/wiki/1',
        'base_uri() for wiki in domain with path prefix' );
}

my $dbh = mock_dbh();

{
    $dbh->{mock_start_insert_id} = [ q{"Wiki"}, 42 ];
    $dbh->{mock_start_insert_id} = [ q{"Page"}, 3 ];

    my $wiki =
        Silki::Schema::Wiki->insert( title      => 'Some Wiki',
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
               [ 'Welcome to Some Wiki', 3, 1, 'FrontPage', 99 ],
               'Creating a wiki also creates a front page (page revision)' );
}
