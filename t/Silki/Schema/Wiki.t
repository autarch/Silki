use strict;
use warnings;

use Test::More;

use lib 't/lib';
use Silki::Test::RealSchema;

use DateTime;
use DateTime::Format::Pg;
use Silki::Schema::Domain;
use Silki::Schema::User;
use Silki::Schema::Wiki;

{
    my $wiki = Silki::Schema::Wiki->new( title => 'First Wiki' );

    is(
        $wiki->uri(), "/wiki/first-wiki",
        'uri for wiki'
    );

    my $domain = Silki::Schema::Domain->DefaultDomain();

    my $hostname = $domain->web_hostname();

    is(
        $wiki->uri( with_host => 1 ), "http://$hostname/wiki/first-wiki",
        'uri with host for wiki'
    );

    my @pages = $wiki->pages()->all();

    is(
        scalar @pages, 2,
        'inserting a new wiki creates two pages'
    );

    is_deeply(
        [ sort map { $_->title() } @pages ],
        [ 'Front Page', 'Help' ],
        'new pages are called Front Page and Help'
    );
}

{
    my $wiki = Silki::Schema::Wiki->new( title => 'First Wiki' );

    my %perms = (
        Guest         => { map { $_ => 1 } qw( Read Edit ) },
        Authenticated => { map { $_ => 1 } qw( Read Edit ) },
        Member        => {
            map { $_ => 1 } qw( Read Edit Delete Upload )
        },
        Admin => {
            map { $_ => 1 } qw( Read Edit Delete Upload Invite Manage )
        },
    );

    is_deeply(
        $wiki->permissions(), \%perms,
        'permissions hash matches expected perm set for public wiki'
    );

    is(
        $wiki->permissions_name(), 'public',
        'permissions name is public'
    );

    $wiki->set_permissions('private');

    %perms = (
        Member        => {
            map { $_ => 1 } qw( Read Edit Delete Upload )
        },
        Admin => {
            map { $_ => 1 } qw( Read Edit Delete Upload Invite Manage )
        },
    );

    is_deeply(
        $wiki->permissions(), \%perms,
        'permissions hash matches expected perm set for private wiki'
    );

    is(
        $wiki->permissions_name(), 'private',
        'permissions name is private'
    );
}

{
    my $wiki = Silki::Schema::Wiki->new( title => 'First Wiki' );

    is( $wiki->revision_count(), 2, 'wiki has two revisions' );

    my @revs = $wiki->revisions()->all();

    # We need to sort the revs because the creation_datetime for the two pages
    # could be identical.
    is_deeply(
        [
            map { [ $_->[0]->title(), $_->[1]->revision_number() ] }
            sort { $a->[0]->title() cmp $b->[0]->title() } @revs
        ],
        [
            [ 'Front Page', 1 ],
            [ 'Help',       1 ],
        ],
        'revisions returns expected revisions'
    );

    is(
        $wiki->front_page_title(), 'Front Page',
        'front page title is Front Page'
    );

    is(
        $wiki->orphaned_page_count(), 0,
        'wiki has no orphaned pages'
    );

    Silki::Schema::Page->insert_with_content(
        title   => 'Orphan',
        wiki_id => $wiki->wiki_id(),
        user_id => Silki::Schema::User->SystemUser()->user_id(),
        content => 'Whatever',
    );

    is(
        $wiki->orphaned_page_count(), 1,
        'wiki has one orphaned page'
    );
}

done_testing();
