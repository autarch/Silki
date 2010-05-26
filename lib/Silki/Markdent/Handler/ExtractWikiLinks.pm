package Silki::Markdent::Handler::ExtractWikiLinks;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '0.01';

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

my @types = map { 'Silki::Markdent::Event::' . $_ } qw( WikiLink FileLink ImageLink );

sub handle_event {
    my $self  = shift;
    my $event = shift;

    return unless any {  $event->isa($_) } @types;

    my $link_data;
    if ( $event->isa('Silki::Markdent::Event::WikiLink') ) {
        $link_data = $self->_resolve_page_link( $event->link_text() );
    }
    else {
        $link_data = $self->_resolve_file_link( $event->link_text() );
    }

    return unless $link_data;

    $self->_add_link( $event->link_text() => $link_data );

    return;
}

1;
