package Silki::Schema::PageTag;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Schema;

use Fey::ORM::Table;

my $Schema = Silki::Schema->Schema();

{
    has_policy 'Silki::Schema::Policy';

    has_table( $Schema->table('PageTag') );
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a tag for a page
