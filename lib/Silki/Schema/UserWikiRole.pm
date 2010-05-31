package Silki::Schema::UserWikiRole;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Schema;

use Fey::ORM::Table;

has_policy 'Silki::Schema::Policy';

my $Schema = Silki::Schema->Schema();

has_table( $Schema->table('UserWikiRole') );

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a user's role in a specific wiki
