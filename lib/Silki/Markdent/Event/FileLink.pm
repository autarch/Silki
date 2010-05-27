package Silki::Markdent::Event::FileLink;

use strict;
use warnings;

use Markdent::Types qw( Str );

use namespace::autoclean;
use Moose;
use MooseX::StrictConstructor;

has link_text => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has display_text => (
    is        => 'ro',
    isa       => Str,
    predicate => 'has_display_text',
);

with 'Markdent::Role::Event';

__PACKAGE__->meta()->make_immutable();

1;

