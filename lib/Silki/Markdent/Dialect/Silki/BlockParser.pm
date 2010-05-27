package Silki::Markdent::Dialect::Silki::BlockParser;

use strict;
use warnings;

use namespace::autoclean;
use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

extends 'Markdent::Dialect::Theory::BlockParser';

__PACKAGE__->meta()->make_immutable();

1;
