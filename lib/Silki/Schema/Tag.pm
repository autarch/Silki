package Silki::Schema::Tag;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Schema;

use Fey::ORM::Table;

my $Schema = Silki::Schema->Schema();

{
    has_policy 'Silki::Schema::Policy';

    has_table( $Schema->table('Tag') );
}

__PACKAGE__->meta()->make_immutable();

1;
