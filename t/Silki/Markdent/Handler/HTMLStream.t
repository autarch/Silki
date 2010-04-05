use strict;
use warnings;

use Test::Most;

use lib 't/lib';
use Silki::Test::RealSchema;

use Silki::Markdent::Handler::HTMLStream;
use Silki::Schema::User;
use Silki::Schema::Wiki;

my $account = Silki::Schema::Account->new( name => 'Default Account' );
my $user = Silki::Schema::User->SystemUser();

my $wiki = Silki::Schema::Wiki->insert(
    title      => 'Public',
    short_name => 'public',
    domain_id  => Silki::Schema::Domain->DefaultDomain()->domain_id(),
    user_id    => $user->user_id(),
    account_id => $account->account_id(),
);

$wiki->set_permissions('public');

my $buffer = q{};
open my $fh, '>', \$buffer;

my $stream = Silki::Markdent::Handler::HTMLStream->new(
    output => $fh,
    user   => $user,
    wiki   => $wiki,
);

{
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
        'link to nonexistent page, no alternate link text'
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
        'link to nonexistent page, with alternate link text'
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

    $stream->wiki_link( link_text => $file_link, display_text => 'test file' );

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

done_testing();
