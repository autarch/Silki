package Silki::Schema::Page;

use strict;
use warnings;

use Fey::Placeholder;
use Silki::Config;
use Silki::Schema::PageRevision;
use Silki::Schema;
use Silki::Schema::Wiki;
use URI::Escape qw( uri_escape_utf8 );

use Fey::ORM::Table;

with 'Silki::Role::Schema::URIMaker';

has_policy 'Silki::Schema::Policy';

has_table( Silki::Schema->Schema()->table('Page') );

has_one( Silki::Schema->Schema()->table('User') );

has_one( Silki::Schema->Schema()->table('Wiki') );

has_many 'revisions' =>
    ( table    => Silki::Schema->Schema()->table('PageRevision'),
      order_by =>
      [ Silki::Schema->Schema()->table('PageRevision')->column('revision_number'), 'DESC' ],
    );

has_one 'most_recent_revision' =>
    ( table       => Silki::Schema->Schema()->table('PageRevision'),
      select      => __PACKAGE__->_most_recent_revision_select(),
      bind_params => sub { $_[0]->page_id() },
    );

sub _base_uri_path
{
    my $self = shift;

    return $self->wiki()->_base_uri_path() . '/p/' . $self->uri_path();
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

    $page_p{uri_path} = $class->_title_to_uri_path( $p{title} );

    my $page;
    $class->SchemaClass()->RunInTransaction
        ( sub
          {
              $page = $class->SUPER::insert(%page_p);

              my $revision =
                  Silki::Schema::PageRevision->insert
                      ( %p,
                        revision_number => 1,
                        page_id         => $page->page_id(),
                        user_id         => $page->user_id(),
                      );
          }
        );

    return $page;
}

sub _title_to_uri_path
{
    my $self  = shift;
    my $title = shift;

    return uri_escape_utf8($title);
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
