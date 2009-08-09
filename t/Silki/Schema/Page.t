use strict;
use warnings;

use Test::More tests => 6;

use DateTime;
use DateTime::Format::Pg;
use Silki::Schema::Domain;
use Silki::Schema::Page;
use Silki::Schema::Wiki;

use lib 't/lib';
use Silki::Test qw( mock_dbh );


my $dbh = mock_dbh();

{
    $dbh->{mock_start_insert_id} = [ q{"Page"}, 100 ];

    my $page = Silki::Schema::Page->insert_with_content( title   => 'SomePage',
                                                         content => 'This is a page',
                                                         user_id => 12,
                                                         wiki_id => 42,
                                                       );

    my @inserts =
        map { $_->bound_params() }
        grep { $_->statement() =~ /^INSERT/ }
        @{ $dbh->{mock_all_history} };

    is_deeply( $inserts[0],
               [ 12, 42 ],
               'Page was inserted as expected' );

    is_deeply( $inserts[1],
               [ 'This is a page', 100, 1, 'SomePage', 12 ],
               'Inserting a page also inserts the first page revision' );
}

{
    my $page = Silki::Schema::Page->new( page_id     => 20,
                                         _from_query => 1,
                                       );

    $dbh->{mock_clear_history} = 1;

    my $now = DateTime::Format::Pg->format_timestamp( DateTime->now( time_zone => 'UTC' ) );

    $dbh->{mock_add_resultset} =
        [ [ qw( content creation_datetime is_restoration_of_revision_number
                page_id revision_number title user_id ) ],
          [ 'This is a page', $now, undef,
            20, 15, 'SomePage', 99 ],
        ];

    my $revision = $page->most_recent_revision();

    is( $revision->revision_number(), 15,
        'most_recent_revision() returns a single revision, rev 15' );
}

{
    my $domain =
        Silki::Schema::Domain->new( domain_id    => 1,
                                    hostname     => 'host.example.com',
                                    path_prefix  => '/prefix',
                                    requires_ssl => 0,
                                    _from_query  => 1,
                                  );

    my $wiki =
        Silki::Schema::Wiki->new( wiki_id    => 1,
                                  domain_id  => 1,
                                  title      => 'Some Wiki',
                                  short_name => 'some-wiki',
                                  _from_query => 1,
                                );

    no warnings 'redefine';
    local *Silki::Schema::Wiki::domain = sub { return $domain };
    local *Silki::Schema::Page::wiki   = sub { return $wiki };

    my $page = Silki::Schema::Page->new( page_id     => 2,
                                         _from_query => 1,
                                       );

    is( $page->uri(), 'http://host.example.com/prefix/wiki/1/page/2',
        '$page->uri()' );

    is( $page->uri_for_domain($domain), '/prefix/wiki/1/page/2',
        '$page->uri_for_domain() - same domain' );

    my $other_domain =
        Silki::Schema::Domain->new( domain_id    => 2,
                                    hostname     => 'another.example.com',
                                    path_prefix  => '/prefix2',
                                    requires_ssl => 0,
                                    _from_query  => 1,
                                  );

    is( $page->uri_for_domain($other_domain), 'http://host.example.com/prefix/wiki/1/page/2',
        '$page->uri_for_domain() - different domain' );
}
