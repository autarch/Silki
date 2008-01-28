package Silk::Model::Wiki;

use strict;
use warnings;

use Silk::Config;
use Silk::Model::Domain;
use Silk::Model::Schema;

use Fey::Class::Table;
use MooseX::ClassAttribute;

has_table( Silk::Model::Schema->Schema()->table('Wiki') );

has_one( Silk::Model::Schema->Schema()->table('Domain') );


sub base_uri
{
    my $self = shift;

    my $uri = $self->domain()->base_uri();

    $uri->path( '/wiki/' . $self->short_name() );

    return $uri;
}

no Fey::Class::Table;
no Moose;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();


1;

__END__


