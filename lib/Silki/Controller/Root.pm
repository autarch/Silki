package Silki::Controller::Root;

use strict;
use warnings;
use namespace::autoclean;

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

__PACKAGE__->config( namespace => q{} );

sub robots_txt : Path('/robots.txt') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $c->response()->content_type('text/plain');
    $c->response()->body("User-agent: *\nDisallow: /\n");
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Controller class for the root of the URI namespace
