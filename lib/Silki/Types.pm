package Silki::Types;

use strict;
use warnings;

use base 'MooseX::Types::Combine';

__PACKAGE__->provide_types_from(
    qw( Silki::Types::Internal MooseX::Types::Moose MooseX::Types::Path::Class ));

1;
