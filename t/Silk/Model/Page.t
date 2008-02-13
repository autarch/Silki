use strict;
use warnings;

use Test::More tests => 2;

use DateTime;
use DateTime::Format::Pg;
use Silk::Model::Page;

use lib 't/lib';
use Silk::Test qw( mock_dbh );


my $dbh = mock_dbh();


{
    $dbh->{mock_start_insert_id} = [ q{"Page"}, 100 ];

    $dbh->{mock_add_resultset} = [];

    $dbh->{mock_add_resultset} =
        [ [ qw( is_archived user_id wiki_id ) ],
          [ 0, 12, 42 ],
        ];

    $dbh->{mock_add_resultset} = [];

    my $now = DateTime::Format::Pg->format_timestamp( DateTime->now( time_zone => 'UTC' ) );

    $dbh->{mock_add_resultset} =
        [ [ qw( content creation_datetime is_restoration_of_revision_number
                title user_id ) ],
          [ 'This is a page', $now, undef,
            'SomePage', 99 ],
        ];

    my $page = Silk::Model::Page->insert( title   => 'SomePage',
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
