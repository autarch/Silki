package Silki::Controller::Wiki;

use strict;
use warnings;

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

sub _set_wiki : Chained : PathPart('w') : CaptureArgs(1)
{
    my $self      = shift;
    my $c         = shift;
    my $wiki_name = shift;

    my $wiki = Silki::Schema::Wiki->new( short_name => $wiki_name );

    unless ($wiki)
    {
        $self->redirect_and_detach( $self->domain()->uri( with_host => 1 ) );
    }
}

sub no_page : Chained('_set_wiki') : PathPart('page') : Args(0) : ActionClass('+Silki::Action::REST') { }

sub no_page_GET_html
{
    my $self = shift;
    my $c    = shift;

    $c->stash->{template} = '/wiki/dashboard';
}

sub page : Chained('_set_wiki') : PathPart('page') : Args(1) : ActionClass('+Silki::Action::REST') { }

sub page_GET_html
{
    my $self = shift;
    my $c    = shift;

    
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
