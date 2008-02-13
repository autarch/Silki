use strict;
use warnings;

use Test::More tests => 4;

use DateTime;
use DateTime::Format::Pg;
use DBI;
use Digest::SHA qw( sha512_base64 );
use Silk::Model::User;

use lib 't/lib';
use Silk::Test qw( mock_dbh );


my $dbh = mock_dbh();

{
    $dbh->{mock_last_insert_id} = [ 'User', 1 ];

    my %user_data = ( email_address => 'user@example.com',
                      display_name  => 'Example User',
                      password      => 'password',
                    );

    my $now = DateTime::Format::Pg->format_timestamp( DateTime->now( time_zone => 'UTC' ) );

    # I'm not sure there's much point in setting this, since we don't
    # need to look at it.
    $dbh->{mock_add_resultset} = [];

    $dbh->{mock_add_resultset} =
        [ [ qw( created_by_user_id creation_datetime date_format
                email_address is_admin is_system_user
                last_modified_datetime password display_name
                time_format timezone user_id username ) ],
          [ undef, $now, '%m/%d/%Y',
            $user_data{email_address}, 0, 0,
            $now, sha512_base64( $user_data{password} ), $user_data{display_name},
            '%I:%M %P', 'UTC', 1, $user_data{username} ],
        ];

    my $user = Silk::Model::User->insert(%user_data);

    my $insert_params = $dbh->{mock_all_history}[0]->bound_params();

    is( $insert_params->[2], sha512_base64( $user_data{password} ),
        'password is digested when passed to insert()' );

    is( $insert_params->[3], $user_data{email_address},
        'username defaults to email_address insert()' );
}

{
    my %user_data = ( email_address => 'user2@example.com',
                      display_name  => 'Example User',
                      username      => 'user2',
                    );

    my $now = DateTime::Format::Pg->format_timestamp( DateTime->now( time_zone => 'UTC' ) );

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} = [];

    $dbh->{mock_add_resultset} =
        [ [ qw( created_by_user_id creation_datetime date_format
                email_address is_admin is_system_user
                last_modified_datetime password display_name
                time_format timezone user_id username ) ],
          [ undef, $now, '%m/%d/%Y',
            $user_data{email_address}, 0, 0,
            $now, '*disabled*', $user_data{display_name},
            '%I:%M %P', 'UTC', 1, $user_data{username} ],
        ];

    my $user =
        Silk::Model::User->insert( %user_data,
                                   disable_login => 1,
                                 );

    my $insert_params = $dbh->{mock_all_history}[0]->bound_params();

    is( $insert_params->[2], '*disabled*',
        'password is set to "*disabled*" when disable_login is passed to insert()' );

    is( $insert_params->[3], $user_data{username},
        'username is not overridden if provided to insert()' );
}
