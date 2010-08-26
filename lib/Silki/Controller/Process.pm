package Silki::Controller::Process;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Schema::Process;

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

sub _set_process : Chained('/') : PathPart('process') : CaptureArgs(1) {
    my $self       = shift;
    my $c          = shift;
    my $process_id = shift;

    my $process = Silki::Schema::Process->new( process_id => $process_id );

    if ( $process->wiki_id() ) {
        my $wiki = Silki::Schema::Wiki->new( wiki_id => $process->wiki_id() );
        $self->_require_permission_for_wiki( $c, $wiki, 'Manage' );
    }
    else {
        $self->_require_site_admin($c);
    }

    unless ($process) {
        $c->response()->status(404);
        $c->detach();
    }

    $c->stash()->{process} = $process;
}

sub process : Chained('_set_process') : PathPart('') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub process_GET {
    my $self = shift;
    my $c    = shift;

    $self->status_ok(
        $c,
        entity => $c->stash()->{process}->serialize(),
    );
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Controller class for processes
