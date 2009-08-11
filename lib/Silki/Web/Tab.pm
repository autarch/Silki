package Silki::Web::Tab;

use strict;
use warnings;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;


has 'uri' =>
    ( is       => 'ro',
      isa      => 'Str',
      required => 1,
    );

has 'label' =>
    ( is       => 'ro',
      isa      => 'Str',
      required => 1,
    );

has 'tooltip' =>
    ( is       => 'ro',
      isa      => 'Str',
      required => 1,
    );

has 'is_selected' =>
    ( is      => 'rw',
      isa     => 'Bool',
      default => 0,
    );

__PACKAGE__->meta()->make_immutable();
no Moose;

1;
