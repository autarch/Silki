package Silki::Schema::PageRevision;

use strict;
use warnings;

use Silki::Config;
use Silki::Schema::Page;
use Silki::Schema::Schema;

use Fey::ORM::Table;

has_table( Silki::Schema::Schema->Schema()->table('PageRevision') );

has_one( Silki::Schema::Schema->Schema()->table('Page') );

has_one( Silki::Schema::Schema->Schema()->table('User') );


no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();


1;

__END__
