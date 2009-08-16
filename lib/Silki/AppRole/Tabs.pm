package Silki::AppRole::Tabs;

use strict;
use warnings;

use Tie::IxHash;

use Moose::Role;

has _tabs =>
    ( is       => 'ro',
      isa      => 'Tie::IxHash',
      lazy     => 1,
      default  => sub { Tie::IxHash->new() },
      init_arg => undef,
      handles  => { tabs      => 'Values',
                    _add_tab  => 'Push',
                    tab_by_id => 'FETCH',
                  },
    );

sub add_tab
{
    my $self = shift;
    my $tab  = shift;

    $self->_add_tab( $tab->id() => $tab );
}

1;
