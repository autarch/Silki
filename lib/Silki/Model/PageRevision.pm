package Silki::Model::PageRevision;

use strict;
use warnings;

use Silki::Config;
use Silki::Model::Page;
use Silki::Model::Schema;

use Fey::ORM::Table;

has_table( Silki::Model::Schema->Schema()->table('PageRevision') );

has_one( Silki::Model::Schema->Schema()->table('Page') );

has_one( Silki::Model::Schema->Schema()->table('User') );


no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();


1;

__END__
