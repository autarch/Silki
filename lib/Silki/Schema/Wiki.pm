package Silki::Schema::Wiki;

use strict;
use warnings;

use Silki::Config;
use Silki::Schema::Domain;
use Silki::Schema::Page;
use Silki::Schema;

use Fey::ORM::Table;

with 'Silki::Role::Schema::URIMaker';

has_table( Silki::Schema->Schema()->table('Wiki') );

has_one( Silki::Schema->Schema()->table('Domain') );


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

sub _base_uri_path
{
    my $self = shift;

    return '/w/' . $self->short_name();
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();


1;

__END__


