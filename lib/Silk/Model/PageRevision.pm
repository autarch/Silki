package Silk::Model::PageRevision;

use strict;
use warnings;

use Silk::Config;
use Silk::Model::Page;
use Silk::Model::Schema;

use Fey::ORM::Table;

has_table( Silk::Model::Schema->Schema()->table('PageRevision') );

has_one( Silk::Model::Schema->Schema()->table('Page') );

has_one( Silk::Model::Schema->Schema()->table('User') );


no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();


1;

__END__
