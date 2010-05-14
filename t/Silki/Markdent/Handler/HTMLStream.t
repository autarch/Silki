use strict;
use warnings;

use Test::Most;

use lib 't/lib';
use Silki::Test::RealSchema;

use Silki::Markdent::Handler::HTMLStream;
use Silki::Schema::User;
use Silki::Schema::Wiki;

my $account = Silki::Schema::Account->new( name => 'Default Account' );

my $user = Silki::Schema::User->insert(
    email_address => 'foo@example.com',
    display_name  => 'Example User',
    password      => 'foobar',
    time_zone     => 'America/New_York',
    user          => Silki::Schema::User->SystemUser(),
);

my $wiki = Silki::Schema::Wiki->insert(
    title      => 'Public',
    short_name => 'public',
    domain_id  => Silki::Schema::Domain->DefaultDomain()->domain_id(),
    account_id => $account->account_id(),
    user       => Silki::Schema::User->SystemUser(),
);

$wiki->set_permissions('public');

my $buffer = q{};
open my $fh, '>', \$buffer;

{
    my $stream = Silki::Markdent::Handler::HTMLStream->new(
        output => $fh,
        user   => $user,
        wiki   => $wiki,
    );

    $stream->wiki_link( link_text => 'Front Page' );

    is(
        $buffer,
        q{<a href="/wiki/public/page/Front_Page" class="existing-page">Front Page</a>},
        'link to front page, no alternate link text'
    );

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link(
        link_text    => 'Front Page',
        display_text => 'the front page',
    );

    is(
        $buffer,
        q{<a href="/wiki/public/page/Front_Page" class="existing-page">the front page</a>},
        'link to front page, with alternate link text'
    );

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link( link_text => 'New Page' );

    is(
        $buffer,
        q{<a href="/wiki/public/new_page_form?title=New+Page" class="new-page">New Page</a>},
        'link to non-existent page, no alternate link text'
    );

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link(
        link_text    => 'New Page',
        display_text => 'the new page',
    );

    is(
        $buffer,
        q{<a href="/wiki/public/new_page_form?title=New+Page" class="new-page">the new page</a>},
        'link to non-existent page, with alternate link text'
    );

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link( link_text => 'file:1' );

    is(
        $buffer,
        q{(Link to non-existent file)},
        'link to non-existent file'
    );
}

{
    my $text = "This is some plain text.\n";
    my $file = Silki::Schema::File->insert(
        file_name => 'test.txt',
        mime_type => 'text/plain',
        file_size => length $text,
        contents  => $text,
        user_id   => $user->user_id(),
        wiki_id   => $wiki->wiki_id(),
    );

    my $file_link = 'file:' . $file->file_id();
    my $uri       = $file->uri();

    my $stream = Silki::Markdent::Handler::HTMLStream->new(
        output => $fh,
        user   => $user,
        wiki   => $wiki,
    );

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link( link_text => $file_link );

    is(
        $buffer,
        qq{<a href="$uri" title="Download this file">test.txt</a>},
        'link to existing file, no alternate link text'
    );

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link(
        link_text    => $file_link,
        display_text => 'test file',
    );

    is(
        $buffer,
        qq{<a href="$uri" title="Download this file">test file</a>},
        'link to existing file, with alternate link text'
    );

    $wiki->set_permissions('private');

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link( link_text => $file_link );

    is(
        $buffer,
        qq{Inaccessible file},
        'link to inaccessible file'
    );
}

{
    my $stream = Silki::Markdent::Handler::HTMLStream->new(
        output     => $fh,
        user       => $user,
        wiki       => $wiki,
        for_editor => 1,
    );

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link( link_text => 'New Page' );

    is(
        $buffer,
        q{<a href="/wiki/public/page/New_Page" class="existing-page">New Page</a>},
        'link to non-existent page for editor'
    );
}

{
    $wiki->set_permissions('public');

    my $wiki2 = Silki::Schema::Wiki->insert(
        title      => 'Other',
        short_name => 'other',
        domain_id  => Silki::Schema::Domain->DefaultDomain()->domain_id(),
        account_id => $account->account_id(),
        user       => $user,
    );

    $wiki2->set_permissions('public');

    my $stream = Silki::Markdent::Handler::HTMLStream->new(
        output => $fh,
        user   => $user,
        wiki   => $wiki,
    );

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link( link_text => 'other/Front Page' );

    is(
        $buffer,
        q{<a href="/wiki/other/page/Front_Page" class="existing-page">Front Page (Other)</a>},
        'link to another wiki front page, no alternate link text'
    );

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link(
        link_text    => 'other/Front Page',
        display_text => 'the front page',
    );

    is(
        $buffer,
        q{<a href="/wiki/other/page/Front_Page" class="existing-page">the front page</a>},
        'link to another wiki front page, with alternate link text'
    );

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link( link_text => 'other/New Page' );

    is(
        $buffer,
        q{<a href="/wiki/other/new_page_form?title=New+Page" class="new-page">New Page (Other)</a>},
        'link to another wiki non-existent page, no alternate link text'
    );

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link(
        link_text    => 'other/New Page',
        display_text => 'the new page',
    );

    is(
        $buffer,
        q{<a href="/wiki/other/new_page_form?title=New+Page" class="new-page">the new page</a>},
        'link to another wiki non-existent page, with alternate link text'
    );

    my $text = "This is some plain text.\n";
    my $file = Silki::Schema::File->insert(
        file_name => 'test2.txt',
        mime_type => 'text/plain',
        file_size => length $text,
        contents  => $text,
        user_id   => $user->user_id(),
        wiki_id   => $wiki2->wiki_id(),
    );

    my $file_link = 'other/file:' . $file->file_id();
    my $uri       = $file->uri();

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link( link_text => $file_link );

    is(
        $buffer,
        qq{<a href="$uri" title="Download this file">test2.txt (Other)</a>},
        'link to another wiki existing file, no alternate link text'
    );

    $buffer = q{};
    seek $fh, 0, 0;

    $stream->wiki_link(
        link_text    => $file_link,
        display_text => 'test file',
    );

    is(
        $buffer,
        qq{<a href="$uri" title="Download this file">test file</a>},
        'link to another wiki existing file, with alternate link text'
    );
}

done_testing();
