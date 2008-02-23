package Silki::Model::Page;

use strict;
use warnings;

use Fey::Placeholder;
use Silki::Config;
use Silki::Model::PageRevision;
use Silki::Model::Schema;
use Silki::Model::Wiki;

use Fey::ORM::Table;

has_table( Silki::Model::Schema->Schema()->table('Page') );

has_one( Silki::Model::Schema->Schema()->table('User') );

has_one( Silki::Model::Schema->Schema()->table('Wiki') );

has_many 'revisions' =>
    ( table    => Silki::Model::Schema->Schema()->table('PageRevision'),
      order_by =>
      [ Silki::Model::Schema->Schema()->table('PageRevision')->column('revision_number'), 'DESC' ],
    );

has_one 'most_recent_revision' =>
    ( table       => Silki::Model::Schema->Schema()->table('PageRevision'),
      select      => __PACKAGE__->_most_recent_revision_select(),
      bind_params => sub { $_[0]->page_id() },
    );

sub uri
{
    my $self = shift;

    my $uri = $self->wiki()->base_uri();

    my $path = $uri->path() . '/page/' . $self->page_id();

    $uri->path($path);

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
    $class->SchemaClass()->RunInTransaction
        ( sub
          {
              $page = $class->SUPER::insert(%page_p);

              my $revision =
                  Silki::Model::PageRevision->insert
                      ( %p,
                        revision_number => 1,
                        page_id         => $page->page_id(),
                        user_id         => $page->user_id(),
                      );
          }
        );

    return $page;
}

sub _most_recent_revision_select
{
    my $self = shift;

    my $schema = $self->SchemaClass()->Schema();

    my $select = $self->SchemaClass()->SQLFactoryClass()->new_select();

    $select->select( $schema->table('PageRevision') )
           ->from( $schema->table('PageRevision') )
           ->where( $schema->table('PageRevision')->column('page_id'),
                    '=', Fey::Placeholder->new() )
           ->order_by( $schema->table('PageRevision')->column('revision_number'), 'DESC' )
           ->limit(1);

    return $select;
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
