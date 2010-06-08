package Silki::Markdent::Handler::HeaderCount;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Types qw( Int );

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

with 'Markdent::Role::Handler';

has count => (
    traits   => ['Counter'],
    is       => 'ro',
    isa      => Int,
    init_arg => undef,
    default  => 0,
    handles  => {
        _saw_header => 'inc',
    },
);

sub handle_event {
    my $self  = shift;
    my $event = shift;

    return unless $event->isa('Markdent::Event::StartHeader');

    $self->_saw_header if $event->level() <= 4;

    return;
}

__PACKAGE__->meta()->make_immutable();

1;

