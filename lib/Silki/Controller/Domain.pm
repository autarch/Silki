package Silki::Controller::Domain;

use strict;
use warnings;
use namespace::autoclean;

use Silki::I18N qw( loc );
use Silki::Schema::Domain;

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

with qw(
    Silki::Role::Controller::Pager
);

sub new_domain_form : Path('/new_domain_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_site_admin($c);

    $c->stash()->{template} = '/domain/new-domain-form';
}

sub domain_collection : Path('/domains') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub domain_collection_GET_html {
    my $self = shift;
    my $c    = shift;

    $self->_require_site_admin($c);

    my ( $limit, $offset ) = $self->_make_pager( $c, Silki::Schema::Domain->Count() );

    $c->stash()->{domains} = Silki::Schema::Domain->All(
        limit  => $limit,
        offset => $offset,
    );

    $c->stash()->{template} = '/domain/domains';
}

sub domain_collection_POST {
    my $self = shift;
    my $c    = shift;

    $self->_require_site_admin($c);

    my %form_data = $c->request()->domain_params();

    my $domain = eval { Silki::Schema::Domain->insert(%form_data) };

    if ( my $e = $@ ) {
        $c->redirect_with_error(
            error => $e,
            uri => $c->domain()->application_uri( path => 'new_domain_form' ),
            form_data => \%form_data,
        );
    }

    $c->redirect_and_detach( $domain->uri() );
}

__PACKAGE__->meta()->make_immutable();

1;
