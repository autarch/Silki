use strict;
use warnings;

use Test::More;

eval "use Test::Spelling";
plan skip_all => "Test::Spelling required for testing POD coverage"
    if $@;

my @stopwords;
for (<DATA>) {
    chomp;
    push @stopwords, $_
        unless /\A (?: \# | \s* \z)/msx;    # skip comments, whitespace
}

add_stopwords(@stopwords);
set_spell_cmd('aspell list -l en');

# This prevents a weird segfault from the aspell command - see
# https://bugs.launchpad.net/ubuntu/+source/aspell/+bug/71322
local $ENV{LC_ALL} = 'C';
all_pod_files_spelling_ok();

__DATA__
CGI
FastCGI
INI
JS
MACs
OpenID
PSGI
PayPal
Postgress
Sendfile
Silki
Silki's
Storable
SystemLog
Testserver
UI
Wikis
antispam
citext
cgi
changeme
contrib
dir
dirs
dzil
exisiting
fastcgi
geekery
hostname
hostnames
javascript
login
minifies
minifying
msgid
namespace
plugins
prepends
prereqs
runtime
spamminess
uber
uri
username
usign
wiki
wikis
wikitext
writeable
www
