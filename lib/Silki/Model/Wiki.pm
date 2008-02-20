package Silki::Model::Wiki;

use strict;
use warnings;

use Silki::Config;
use Silki::Model::Domain;
use Silki::Model::Page;
use Silki::Model::Schema;

use Fey::ORM::Table;

has_table( Silki::Model::Schema->Schema()->table('Wiki') );

has_one( Silki::Model::Schema->Schema()->table('Domain') );


sub insert
{
    my $class = shift;
    my %p     = @_;

    my $wiki;

    $class->SchemaClass()->InTransaction
        ( sub
          {
              $wiki = $class->SUPER::insert(%p);

              Silki::Model::Page->insert
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

    my $path = $self->domain()->path_prefix() . '/wiki/' . $self->wiki_id();
    $uri->path($path);

    return $uri;
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();


1;

__END__


