use strict;
use warnings;
use utf8;

use Test::Differences;
use Test::More;

use Test::Requires {
    'HTML::Tidy' => '1.54',
};

use lib 't/lib';
use Silki::Test::RealSchema;

use Silki::Formatter::WikiToHTML;
use Silki::Schema::Page;
use Silki::Schema::Role;
use Silki::Schema::User;
use Silki::Schema::Wiki;

my $wiki1 = Silki::Schema::Wiki->new( short_name => 'first-wiki' );
$wiki1->set_permissions('private');

my $wiki2 = Silki::Schema::Wiki->new( short_name => 'second-wiki' );
$wiki2->set_permissions('public');

my $sys_user = Silki::Schema::User->SystemUser();

for my $num ( 1 .. 6 ) {
    Silki::Schema::Page->insert_with_content(
        title   => 'Page ' . $num,
        user_id => $sys_user->user_id(),
        wiki_id => ( $num < 4 ? $wiki1->wiki_id() : $wiki2->wiki_id() ),
        content => 'Whatever',
    );
}

my $user = Silki::Schema::User->insert(
    email_address => 'user@example.com',
    display_name  => 'Example User',
    password      => 'xyz',
    time_zone     => 'America/New_York',
    user          => $sys_user,
);

$wiki1->add_user(
    user => $user,
    role => Silki::Schema::Role->Member(),
);

{
    my $page = Silki::Schema::Page->new(
        title   => 'Front Page',
        wiki_id => $wiki1->wiki_id(),
    );

    my $formatter = Silki::Formatter::WikiToHTML->new(
        user => $user,
        page => $page,
        wiki => $wiki1,
    );

    my $html = $formatter->wiki_to_html(<<'EOF');
Link to ((Page 1))

Link to ((Page 2))

Link to ((Page Which Does Not Exist))

Link to ((Second Wiki/Page 4))

Link to ((Second Wiki/Page 5))

Link to ((Second Wiki/Page Which Does Not Exist))

Link to ((Page 3))

Link to ((Page 2))

Link to ((Bad Wiki/Page Which Does Not Exist))
EOF

    my $expect_html = <<'EOF';
<p>
Link to <a href="/wiki/first-wiki/page/Page_1" class="existing-page" title="Read Page 1">Page 1</a>
</p>

<p>
Link to <a href="/wiki/first-wiki/page/Page_2" class="existing-page" title="Read Page 2">Page 2</a>
</p>

<p>
Link to <a href="/wiki/first-wiki/new_page_form?title=Page+Which+Does+Not+Exist"
           class="new-page" title="This page has not yet been created">Page Which Does Not Exist</a>
</p>

<p>
Link to <a href="/wiki/second-wiki/page/Page_4" class="existing-page" title="Read Page 4">Page 4 (Second Wiki)</a>
</p>

<p>
Link to <a href="/wiki/second-wiki/page/Page_5" class="existing-page" title="Read Page 5">Page 5 (Second Wiki)</a>
</p>

<p>
Link to <a href="/wiki/second-wiki/new_page_form?title=Page+Which+Does+Not+Exist"
           class="new-page" title="This page has not yet been created">Page Which Does Not Exist (Second Wiki)</a>
</p>

<p>
Link to <a href="/wiki/first-wiki/page/Page_3" class="existing-page" title="Read Page 3">Page 3</a>
</p>

<p>
Link to <a href="/wiki/first-wiki/page/Page_2" class="existing-page" title="Read Page 2">Page 2</a>
</p>

<p>
Link to (link to a non-existent wiki in a page link - Bad Wiki/Page Which Does Not Exist)</p>
</p>
EOF

    test_html(
        $html, $expect_html,
        'html output for a variety of page links'
    );
}

{
    my $page1 = Silki::Schema::Page->new(
        title   => 'Front Page',
        wiki_id => $wiki1->wiki_id(),
    );

    Silki::Schema::File->insert(
        file_id   => 1,
        filename  => 'foo1.jpg',
        mime_type => 'image/jpeg',
        file_size => 3,
        contents  => 'foo',
        user_id   => $sys_user->user_id(),
        page_id   => $page1->page_id(),
    );

    my $page2 = Silki::Schema::Page->new(
        title   => 'Front Page',
        wiki_id => $wiki2->wiki_id(),
    );

    Silki::Schema::File->insert(
        file_id   => 2,
        filename  => 'foo2.jpg',
        mime_type => 'image/jpeg',
        file_size => 3,
        contents  => 'foo',
        user_id   => $sys_user->user_id(),
        page_id   => $page2->page_id(),
    );

    Silki::Schema::File->insert(
        file_id   => 3,
        filename  => 'foo3.doc',
        mime_type => 'application/msword',
        file_size => 3,
        contents  => 'foo',
        user_id   => $sys_user->user_id(),
        page_id   => $page1->page_id(),
    );

    my $formatter = Silki::Formatter::WikiToHTML->new(
        user => $user,
        page => $page1,
        wiki => $wiki1,
    );

    my $html = $formatter->wiki_to_html(<<'EOF');
Link to {{file:foo1.jpg}}

Link to {{file:Front Page/foo1.jpg}}

Link to {{file:bad-file1.jpg}}

Link to {{file:Second Wiki/Front Page/foo2.jpg}}

Link to {{file:Second Wiki/Front Page/bad-file2.jpg}}

Link to {{file:Bad Wiki/Front Page/bad-file3.jpg}}

Link to {{file:foo1.jpg}}

Link to {{file:foo3.doc}}

{{image:foo1.jpg}}

{{image:bad-file1.jpg}}

{{image:Second Wiki/Front Page/foo2.jpg}}

{{image:Second Wiki/Front Page/bad-file2.jpg}}

{{image:Bad Wiki/Front Page/bad-file3.jpg}}
EOF

    my $expect_html = <<'EOF';
<p>
Link to <a href="/wiki/first-wiki/file/1" title="View this file">foo1.jpg</a>
</p>

<p>
Link to <a href="/wiki/first-wiki/file/1" title="View this file">foo1.jpg</a>
</p>

<p>
Link to (link to a non-existent file - bad-file1.jpg)
</p>

<p>
Link to <a href="/wiki/second-wiki/file/2" title="View this file">foo2.jpg (Second Wiki)</a>
</p>

<p>
Link to (link to a non-existent file - Second Wiki/Front Page/bad-file2.jpg)
</p>

<p>
Link to (link to a non-existent wiki in a file link - Bad Wiki/Front Page/bad-file3.jpg)
</p>

<p>
Link to <a href="/wiki/first-wiki/file/1" title="View this file">foo1.jpg</a>
</p>

<p>
Link to <a href="/wiki/first-wiki/file/3" title="Download this file">foo3.doc</a>
</p>

<p>
<a href="/wiki/first-wiki/file/1" title="View this file"><img src="/wiki/first-wiki/file/1/small" alt="foo1.jpg" /></a>
</p>

<p>
(link to a non-existent file - bad-file1.jpg)
</p>

<p>
<a href="/wiki/second-wiki/file/2" title="View this file"><img src="/wiki/second-wiki/file/2/small" alt="foo2.jpg" /></a>
</p>

<p>
(link to a non-existent file - Second Wiki/Front Page/bad-file2.jpg)
</p>

<p>
(link to a non-existent wiki in a file link - Bad Wiki/Front Page/bad-file3.jpg)
</p>
EOF

    test_html(
        $html, $expect_html,
        'html output for a variety of file and image links'
    );
}

done_testing();

sub test_html {
    my $got    = shift;
    my $expect = shift;
    my $desc   = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $real_expect = <<"EOF";
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
          "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
  <title>Test</title>
</head>
<body>
$expect
</body>
</html>
EOF

    my $tidy = HTML::Tidy->new(
        {
            doctype           => 'transitional',
            'sort-attributes' => 'alpha',
            output_xhtml      => 1,
        }
    );

    $got    = $tidy->clean($got);
    $expect = $tidy->clean($real_expect);

    s{.+<body>\s*|\s*</body>.+}{}gs for $got, $expect;

    eq_or_diff( $got, $expect, $desc );
}
