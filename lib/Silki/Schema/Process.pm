package Silki::Schema::Process;

use strict;
use warnings;
use namespace::autoclean;

use Fey::Literal::Function;
use Silki::Schema;

use Fey::ORM::Table;

my $Schema = Silki::Schema->Schema();

{
    has_policy 'Silki::Schema::Policy';

    has_table( $Schema->table('Process') );
}

with 'Silki::Role::Schema::Serializes';

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a separate process

