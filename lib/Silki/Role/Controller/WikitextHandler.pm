package Silki::Role::Controller::WikitextHandler;

use strict;
use warnings;
use namespace::autoclean;

use Moose::Role;

sub _wikitext_from_form {
    my $self = shift;
    my $c    = shift;
    my $wiki = shift;

    if ( $c->request()->params()->{format} eq 'html' ) {
        my $formatter = Silki::Formatter::HTMLToWiki->new( wiki => $wiki );

        return $formatter->html_to_wikitext(
            $c->request()->params()->{content} );
    }
    else {
        return $c->request()->params()->{content};
    }
}

1;
