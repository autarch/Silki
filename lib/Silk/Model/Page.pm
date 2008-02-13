package Silk::Model::Page;

use strict;
use warnings;

use Silk::Config;
use Silk::Model::PageRevision;
use Silk::Model::Schema;
use Silk::Model::Wiki;

use Fey::ORM::Table;

has_table( Silk::Model::Schema->Schema()->table('Page') );

has_one( Silk::Model::Schema->Schema()->table('User') );

has_one( Silk::Model::Schema->Schema()->table('Wiki') );

has_many 'revisions' =>
    ( table    => Silk::Model::Schema->Schema()->table('PageRevision'),
      order_by =>
      [ Silk::Model::Schema->Schema()->table('PageRevision')->column('revision_number'), 'DESC' ],
    );


sub uri
{
    my $self = shift;

    my $uri = $self->wiki()->uri();

    my $path = $uri->path() . '/page/' . $self->page_id();

    return $uri;
}

sub uri_for_domain
{
    my $self   = shift;
    my $domain = shift;

    my $uri = $self->uri();

    if ( $self->wiki()->domain_id() == $domain->domain_id() )
    {
        return $uri->path();
    }
    else
    {
        return $uri;
    }
}

sub insert
{
    my $class = shift;
    my %p     = @_;

    my %page_p =
        ( map { $_ => delete $p{$_} }
          grep { exists $p{$_} }
          map { $_->name() }
          $class->Table()->columns()
        );

    my $page;
    $class->SchemaClass()->InTransaction
        ( sub
          {
              $page = $class->SUPER::insert(%page_p);

              my $revision =
                  Silk::Model::PageRevision->insert
                      ( %p,
                        revision_number => 1,
                        page_id         => $page->page_id(),
                        user_id         => $page->user_id(),
                      );
          }
        );

    return $page;
}


no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();


1;

__END__
