package Silki::Schema::Wiki;

use strict;
use warnings;

use Silki::Config;
use Silki::Schema::Domain;
use Silki::Schema::Page;
use Silki::Schema::Schema;

use Fey::ORM::Table;

has_table( Silki::Schema::Schema->Schema()->table('Wiki') );

has_one( Silki::Schema::Schema->Schema()->table('Domain') );


sub insert
{
    my $class = shift;
    my %p     = @_;

    my $wiki;

    $class->SchemaClass()->RunInTransaction
        ( sub
          {
              $wiki = $class->SUPER::insert(%p);

              Silki::Schema::Page->insert
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


