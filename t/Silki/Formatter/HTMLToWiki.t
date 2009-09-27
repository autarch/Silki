use strict;
use warnings;

use Test::Differences;
use Test::More tests => 1;

use Silki::Formatter::HTMLToWiki;
use Silki::Schema::User;
use Silki::Schema::Wiki;

my $wiki = Silki::Schema::Wiki->new(
    wiki_id     => 1,
    short_name  => 'first-wiki',
    title       => 'First Wiki',
    _from_query => 1,
);

my $user = Silki::Schema::User->new(
    user_id  => 1,
    username => 'foo@example.com',
);

my $formatter = Silki::Formatter::HTMLToWiki->new(
    user => $user,
    wiki => $wiki,
);

my $html = <<'EOF';
<h2 id="welcometoyournewwiki.">
  Welcome to your new wiki</h2>
<p>
  A <a href="http://www.vegguide.org">wiki</a> is a set of web pages <strong>that can</strong> <em>be</em> read and edited by a group of people. You use simple syntax to add things like <em>italics</em> and <strong>bold</strong> to the text. Wikis are designed to make linking to other pages easy. See the <a class="existing-page" href="/wiki/first-wiki/page/Help">Help</a> page.</p>
<ol>
  <li>
    num</li>
  <li>
    list
    <ol>
      <li>
        2nd level</li>
    </ol>
  </li>
</ol>

<ul>
  <li>
    Unordered list</li>
  <li>
    Item 2</li>
</ul>

<p>
  blah</p>
<ul>
  <li>
    blah</li>
</ul>
<p>
  plain text</p>
<blockquote>
  <blockquote>
    <blockquote>
      <p>
        indented</p>
    </blockquote>
  </blockquote>
</blockquote>
EOF

my $wikitext = $formatter->html_to_wikitext($html);

my $expected = <<'EOF';
## Welcome to your new wiki

A [wiki](http://www.vegguide.org) is a set of web pages **that can** _be_ read and edited by a group of people. You use simple syntax to add things like _italics_ and **bold** to the text. Wikis are designed to make linking to other pages easy. See the [[Help]] page.

1. num
2. list
  1. 2nd level

* Unordered list
* Item 2

blah

* blah

plain text

> > > indented
EOF

eq_or_diff( $wikitext, $expected,
    'wikitext matches expected html -> wikitext result' );
