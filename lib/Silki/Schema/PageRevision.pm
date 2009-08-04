package Silki::Schema::PageRevision;

use strict;
use warnings;

use Silki::Config;
use Silki::Schema::Page;
use Silki::Schema;

use Fey::ORM::Table;

has_table( Silki::Schema->Schema()->table('PageRevision') );

has_one( Silki::Schema->Schema()->table('Page') );

has_one( Silki::Schema->Schema()->table('User') );


no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();


1;

__END__
