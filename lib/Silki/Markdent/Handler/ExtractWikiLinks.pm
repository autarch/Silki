package Silki::Markdent::Handler::ExtractWikiLinks;

use strict;
use warnings;

our $VERSION = '0.01';

use Silki::Types qw( HashRef );

use namespace::autoclean;
use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

with 'Markdent::Role::Handler', 'Silki::Markdent::Role::WikiLinkResolver';

has links => (
    traits   => ['Hash'],
    is       => 'ro',
    isa      => HashRef[HashRef],
    init_arg => undef,
    default  => sub { {} },
    handles  => {
        _add_link => 'set',
    },
);

sub handle_event {
    my $self  = shift;
    my $event = shift;

    return unless $event->isa('Silki::Markdent::Event::WikiLink');

    my $link_data
        = $self->_resolve_page_link( $event->link_text(), $event->display_text() );

    $self->_add_link( $event->link_text() => $link_data );

    return;
}

1;
