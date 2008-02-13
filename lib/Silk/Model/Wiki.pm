package Silk::Model::Wiki;

use strict;
use warnings;

use Silk::Config;
use Silk::Model::Domain;
use Silk::Model::Page;
use Silk::Model::Schema;

use Fey::ORM::Table;

has_table( Silk::Model::Schema->Schema()->table('Wiki') );

has_one( Silk::Model::Schema->Schema()->table('Domain') );


sub insert
{
    my $class = shift;
    my %p     = @_;

    my $wiki;

    $class->SchemaClass()->InTransaction
        ( sub
          {
              $wiki = $class->SUPER::insert(%p);

              Silk::Model::Page->insert
                  ( title   => 'FrontPage',
                    content => 'Welcome to ' . $wiki->title(),
                    wiki_id => $wiki->wiki_id(),
                    user_id => $wiki->user_id(),
                  );
          }
        );

    return $wiki;
}

sub base_uri
{
    my $self = shift;

    my $uri = $self->domain()->base_uri();

    my $path = $self->domain()->path_prefix() . '/wiki/' . $self->short_name();
    $uri->path($path);

    return $uri;
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();


1;

__END__


