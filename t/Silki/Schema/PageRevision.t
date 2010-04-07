use strict;
use warnings;

use Test::Most;

use lib 't/lib';
use Silki::Test::RealSchema;

use Silki::Schema::Page;
use Silki::Schema::PageRevision;
use Silki::Schema::User;
use Silki::Schema::Wiki;

my $wiki = Silki::Schema::Wiki->new( short_name => 'first-wiki' );
my $user = Silki::Schema::User->GuestUser();

{
    my $page = Silki::Schema::Page->insert_with_content(
        title   => 'Some Page',
        content => 'This is a page with a link to a [[Pending Page]]',
        user_id => $user->user_id(),
        wiki_id => $wiki->wiki_id(),
    );

    my $rev1     = $page->most_recent_revision();
    my $page_uri = $page->uri();

    is(
        $rev1->uri(),
        "$page_uri/revision/" . $rev1->revision_number(),
        'got expected uri for page revision'
    );

    my $html = <<'EOF';
<p>This is a page with a link to a <a href="/wiki/first-wiki/new_page_form?title=Pending+Page" class="new-page">Pending Page</a>
</p>
EOF

    chomp $html;

    is(
        $rev1->content_as_html( user => $user ),
        $html,
        'content as html - most recent revision'
    );

    $page->add_revision(
        content => 'New content',
        user_id => $user->user_id(),
    );

    is(
        $rev1->content_as_html( user => $user ),
        $html,
        'content as html - older revision'
    );
}

done_testing();
