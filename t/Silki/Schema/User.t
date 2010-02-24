use strict;
use warnings;

use Test::Exception;
use Test::More;

use lib 't/lib';
use Silki::Test::RealSchema;

use DateTime;
use DateTime::Format::Pg;
use Digest::SHA qw( sha512_base64 );
use Silki::Schema::User;

my $dbh = Silki::Schema->DBIManager()->default_source()->dbh();
my $wiki = Silki::Schema::Wiki->new( short_name => 'first-wiki' );

{
    my $email = 'user@example.com';
    my $pw    = 's3cr3t';

    my $user = Silki::Schema::User->insert(
        email_address => $email,
        display_name  => 'Example User',
        password      => $pw,
        time_zone     => 'America/New_York',
    );

    like(
        $user->password(), qr/^{CRYPT}/,
        'user password is encrypted on insert'
    );

    is(
        $user->username(), $email,
        'username defaults to email_address insert()'
    );

    ok(
        $user->check_password($pw),
        'check_password returns true for valid pw'
    );

    ok(
        !$user->check_password('junk'),
        'check_password returns false for invalid pw'
    );

    ok( $user->has_valid_password(), 'user has valid password' );

    ok( $user->has_login_credentials(), 'user has login credentials' );

    ok(
        !$user->is_guest(),
        'regular user is not a guest'
    );

    ok(
        !$user->is_system_user(),
        'regular user is not a system user'
    );

    ok(
        $user->is_authenticated(),
        'regular user is authenticated'
    );

    is(
        $user->set_time_zone_for_dt( DateTime->now( time_zone => 'UTC' ) )
            ->time_zone()->name(),
        'America/New_York',
        'set_time_zone_for_dt sets dt to the correct time zone'
    );
}

{
    my $system = Silki::Schema::User->SystemUser();
    ok(
        !$system->check_password('anything'),
        'check_password is always false for system user'
    );

    ok(
        !$system->is_guest(),
        'system user is not a guest'
    );

    ok(
        !$system->is_authenticated(),
        'system user is not authenticated'
    );

    my $guest = Silki::Schema::User->GuestUser();
    ok(
        $guest->is_guest(),
        'guest user is a guest'
    );

    ok(
        !$guest->is_authenticated(),
        'guest user is not authenticated'
    );
}

{
    my $email = 'user2@example.com';

    my $user = Silki::Schema::User->insert(
        email_address => $email,
        display_name  => 'Example User',
        disable_login => 1,
    );

    is(
        $user->password(), '*disabled*',
        'password is set to "*disabled*" when disable_login is passed to insert()'
    );

    ok( !$user->has_valid_password(), 'user does not have valid password' );

    ok(
        !$user->check_password('anything'),
        'check_password is always false for disabled login'
    );
}


{
    my $email = 'user3@example.com';
    my $pw    = 's3cr3t';

    my $user = Silki::Schema::User->insert(
        email_address       => $email,
        display_name        => 'Example User',
        password            => $pw,
        requires_activation => 1,
    );

    ok( length $user->activation_key(),
        'user has an activation_key when requires_activation is passed to insert()' );

    ok( $user->requires_activation(),
        'requires_activation is true' );

    is(
        $user->activation_uri(),
        '/user/'
            . $user->user_id()
            . '/activation/'
            . $user->activation_key()
            . '/preferences_form',
        'default activation_uri() is for preferences form'
    );

    is(
        $user->activation_uri( view => 'status' ),
        '/user/'
            . $user->user_id()
            . '/activation/'
            . $user->activation_key()
            . '/status',
        'activation_uri() with explicit view'
    );

    $user->update(
        activation_key    => undef,
        preserve_password => 1,
    );

    throws_ok(
        sub { $user->activation_uri() },
        qr/^\QCannot make an activation uri for a user which does not need activation/,
        'cannot get an activation_uri for a user without an activation_key'
    );
}

{
    throws_ok(
        sub {
            Silki::Schema::User->insert(
                email_address => 'fail@example.com',
                display_name  => 'Faily McFail',
            );
        },
        qr/\QYou must provide a password or OpenID./,
        'Cannot insert a user without a pw or openid'
    );

    throws_ok(
        sub {
            Silki::Schema::User->insert(
                email_address => 'fail@example.com',
                display_name  => 'Faily McFail',
                openid_uri    => q{},
            );
        },
        qr/\QYou must provide a password or OpenID./,
        'Cannot insert a user without a pw or openid'
    );
}

{
    my $email = 'user4@example.com';
    my $pw    = 's3cr3t';

    my $user = Silki::Schema::User->insert(
        email_address => $email,
        display_name  => 'Example User',
        password      => $pw,
    );

    throws_ok(
        sub {
            $user->update( password => undef );
        },
        qr/\QYou must provide a password or OpenID./,
        'Cannot update a user to not have a password'
    );

    lives_ok(
        sub {
            $user->update(
                openid_uri => 'http://example.com',
                password   => undef,
            );
        },
        'Can update a user to unset the password but add an openid_uri'
    );

    ok( !$user->has_valid_password(), 'user does not have valid password' );

    ok( $user->has_login_credentials(), 'user has login credentials (openid)' );

    throws_ok(
        sub {
            $user->update( openid_uri => 'not a uri' );
        },
        qr/\QThe OpenID you provided is not a valid URI./,
        'Cannot update a user with an invalid openid_uri (not a uri at all)'
    );

    throws_ok(
        sub {
            $user->update( openid_uri => 'ftp://example.com/dir' );
        },
        qr/\QThe OpenID you provided is not a valid URI./,
        'Cannot update a user with an invalid openid_uri (ftp uri)'
    );

    throws_ok(
        sub {
            Silki::Schema::User->insert(
                email_address => 'user5@example.com',
                display_name  => 'Example User',
                openid_uri    => 'http://example.com',
            );
        },
        qr/The OpenID URI you provided is already in use by another account./,
        'Cannot have two users with the same openid_uri',
    );

    throws_ok(
        sub {
            Silki::Schema::User->insert(
                email_address => 'user4@example.com',
                display_name  => 'Example User',
                password      => 'whatever',
            );
        },
        qr/The email address you provided is already in use by another account./,
        'Cannot have two users with the same email_address',
    );
}

{
    my $admin = Silki::Schema::User->insert(
        email_address => 'admin@example.com',
        password      => 'foo',
        is_admin      => 1,
    );

    my $reg1 = Silki::Schema::User->insert(
        email_address => 'reg1@example.com',
        password      => 'foo',
    );

    my $reg2 = Silki::Schema::User->insert(
        email_address => 'reg2@example.com',
        password      => 'foo',
    );

    ok( $admin->can_edit_user($admin), 'admin can edit self' );
    ok( $admin->can_edit_user($reg1),  'admin can edit other users' );

    ok( $reg1->can_edit_user($reg1), 'regular user can edit self' );
    ok( !$reg1->can_edit_user($reg2),
        'regular user cannot edit other users' );
}

done_testing();
