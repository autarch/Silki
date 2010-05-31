package Silki::Schema::PageLink;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Schema;

use Fey::ORM::Table;

has_policy 'Silki::Schema::Policy';

has_table( Silki::Schema->Schema()->table('PageLink') );

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a link from one page to another
