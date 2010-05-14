package Silki::SeedData;

use strict;
use warnings;

our $VERBOSE;

sub seed_data {
    local $VERBOSE = shift;

    require Silki::Schema::Locale;

    Silki::Schema::Locale->CreateDefaultLocales();

    require Silki::Schema::Country;

    Silki::Schema::Country->CreateDefaultCountries();

    require Silki::Schema::TimeZone;

    Silki::Schema::TimeZone->CreateDefaultZones();

    require Silki::Schema::Domain;

    Silki::Schema::Domain->EnsureRequiredDomainsExist();

    require Silki::Schema::User;

    Silki::Schema::User->EnsureRequiredUsersExist();

    require Silki::Schema::Account;
    require Silki::Schema::Role;

    print "\n" if $VERBOSE;

    my $account = _make_account();
    my $admin   = _make_admin_user($account);
    my $regular = _make_regular_user($account);
    _make_first_wiki( $admin, $regular, $account );
    _make_second_wiki( $admin, $regular, $account );
    _make_third_wiki( $admin, $regular, $account );

}

sub _make_account {
    return Silki::Schema::Account->insert( name => 'Default Account' );
}

sub _make_admin_user {
    my $account = shift;

    my $email
        = 'admin@' . Silki::Schema::Domain->DefaultDomain()->email_hostname();

    my $admin = _make_user( 'Angela D. Min', $email, 1 );

    $account->add_admin($admin);

    return $admin;
}

sub _make_regular_user {
    my $account = shift;

    my $email
        = 'joe@' . Silki::Schema::Domain->DefaultDomain()->email_hostname();

    return _make_user( 'Joe Schmoe', $email );
}

sub _make_user {
    my $name     = shift;
    my $email    = shift;
    my $is_admin = shift;

    my $pw = 'changeme';

    my $user = Silki::Schema::User->insert(
        display_name  => $name,
        email_address => $email,
        password      => $pw,
        time_zone     => 'America/Chicago',
        is_admin      => ( $is_admin ? 1 : 0 ),
        user          => Silki::Schema::User->SystemUser(),
    );

    if ($VERBOSE) {
        my $type = $is_admin ? 'an admin' : 'a regular';

        print <<"EOF";
Created $type user:

  email:    $email
  password: $pw

EOF
    }

    return $user;
}

sub _make_first_wiki {
    my $admin   = shift;
    my $regular = shift;
    my $account = shift;

    my $wiki = _make_wiki( 'First Wiki', 'first-wiki', $account );

    $wiki->set_permissions('public');

    $wiki->add_user( user => $admin, role => Silki::Schema::Role->Admin() );
    $wiki->add_user(
        user => $regular,
        role => Silki::Schema::Role->Member()
    );
}

sub _make_second_wiki {
    my $admin   = shift;
    my $regular = shift;
    my $account = shift;

    my $wiki = _make_wiki( 'Second Wiki', 'second-wiki', $account );

    $wiki->set_permissions('private');

    $wiki->add_user( user => $admin, role => Silki::Schema::Role->Admin() );
    $wiki->add_user(
        user => $regular,
        role => Silki::Schema::Role->Member()
    );
}

sub _make_third_wiki {
    my $admin   = shift;
    my $regular = shift;
    my $account = shift;

    my $wiki = _make_wiki( 'Third Wiki', 'third-wiki', $account );

    $wiki->set_permissions('private');

    $wiki->add_user(
        user => $regular,
        role => Silki::Schema::Role->Member()
    );
}

sub _make_wiki {
    my $title   = shift;
    my $name    = shift;
    my $account = shift;

    require Silki::Schema::Wiki;

    my $wiki = Silki::Schema::Wiki->insert(
        title      => $title,
        short_name => $name,
        domain_id  => Silki::Schema::Domain->DefaultDomain()->domain_id(),
        account_id => $account->account_id(),
        user       => Silki::Schema::User->SystemUser(),
    );

    my $uri = $wiki->uri( with_host => 1 );

    if ($VERBOSE) {
        print <<"EOF";
Created a wiki:

  Title: $title
  URI:   $uri

EOF
    }

    return $wiki;
}

1;
