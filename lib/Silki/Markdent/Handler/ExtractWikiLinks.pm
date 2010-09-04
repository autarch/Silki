package Silki::Markdent::Handler::ExtractWikiLinks;

use strict;
use warnings;
use namespace::autoclean;

use List::AllUtils qw( any );
use Silki::Types qw( HashRef );

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

    my $link_data = $self->_resolve_page_link( $event->link_text() );

    return unless $link_data && $link_data->{wiki};

    $self->_add_link( $event->link_text() => $link_data );

    return;
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Extracts all links from a Silki Markdown document
