use strict;
use warnings;

use Test::Most;

use lib 't/lib';
use Silki::Test::RealSchema;

use Archive::Tar::Wrapper;
use File::Slurp qw( read_file );
use Silki::JSON;
use Silki::Schema::Page;
use Silki::Schema::User;
use Silki::Schema::Wiki;

my $wiki = Silki::Schema::Wiki->new( title => 'First Wiki' );

{
    my @pages = map { _data_for_page( $wiki, $_ ) }
        'Front Page',
        'Scratch Pad';

    my @users = sort { $a->{display_name} cmp $b->{display_name} }
        map { _data_for_user( $wiki, $_ ) }
        grep { $_->display_name() ne 'Guest User' }
        Silki::Schema::User->All()->all();

    my %expect = (
        pages => \@pages,
        users => \@users,
    );

    _test_archive( $wiki->export(), \%expect );
}

done_testing();

sub _data_for_page {
    my $wiki = shift;
    my $title = shift;

    my $page = Silki::Schema::Page->new(
        title   => $title,
        wiki_id => $wiki->wiki_id(),
    );

    return {} unless $page;

    my $ser = $page->serialize();

    my $revisions = $page->revisions();

    while ( my $rev = $revisions->next() ) {
        push @{ $ser->{revisions} }, $rev->serialize();
    }

    return $ser;
}

sub _data_for_user {
    my $wiki = shift;
    my $user = shift;

    my $ser = $user->serialize();

    if ( $user->is_wiki_member($wiki) ) {
        $ser->{role_in_wiki} = $user->role_in_wiki($wiki)->name();
    }

    return $ser;
}

sub _test_archive {
    my $tarball = shift;
    my $expect  = shift;

    my $tar = Archive::Tar::Wrapper->new();
    $tar->read($tarball);

    $tar->list_reset();

    my %pages;
    my %revisions;
    my @users;

    while ( my ( undef, $path ) = @{ $tar->list_next() || [] } ) {

        my $data = Silki::JSON->Decode( scalar read_file($path) );

        if ( $path =~ m{/([^/]+)/page.json} ) {
            $pages{$1} = $data;
        }
        elsif ( $path =~ m{/([^/]+)/revision-\d+.json} ) {
            push @{ $revisions{$1} }, $data;
        }
        elsif ( $path =~ m{/([^/]+)/user-\d+.json} ) {
            push @users, $data;
        }
        else {
            fail("Found bizarre path in tarball: $path");
        }
    }

    my @combined;
    for my $uri_path ( sort keys %pages ) {
        if ( !exists $revisions{$uri_path} ) {
            fail("No revisions for page $pages{$uri_path}{title}");
            next;
        }

        my $page = $pages{$uri_path};
        $page->{revisions} = $revisions{$uri_path};

        push @combined, $page;
    }

    is_deeply(
        \@combined, $expect->{pages},
        'pages in exported tarball'
    );

    is_deeply(
        [ sort { $a->{display_name} cmp $b->{display_name} } @users ],
        $expect->{users},
        'users in exported tarball'
    );
}
