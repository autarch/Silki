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
    isa      => HashRef [HashRef],
    init_arg => undef,
    default  => sub { {} },
    handles  => {
        _add_link => 'set',
    },
);

# The WikiLinkResolver role does everything we need done for event handling.
sub handle_event { }

sub _replace_placeholder {
    my $self      = shift;
    my $id        = shift;
    my $link_data = shift;

    return unless $link_data && $link_data->{wiki};

    $self->_add_link( $id => $link_data );

    return;
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Extracts all links from a Silki Markdown document
