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

has 'most_recent_revision' =>
    ( is       => 'ro',
      isa      => 'Silk::Model::PageRevision',
      lazy     => 1,
      default  => \&_most_recent_revision,
      init_arg => "\0most_recent_revision",
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

# replace with something like ...
#
#
# my $select = ...;
#
# has_one 'most_recent_revision' =>
#     ( table       => $schema->table('PageRevision')
#       select      => $select,
#       bind_params => sub { $_[0]->page_id() },
#     );
sub _most_recent_revision
{
    my $self = shift;

    my $schema = $self->SchemaClass()->Schema();

    my $select = $self->SchemaClass()->SQLFactoryClass()->new_select();

    $select->select( $schema->table('PageRevision') )
           ->where( $schema->table('PageRevision')->column('page_id'),
                    '=', $self->page_id() )
           ->order_by( $schema->table('PageRevision')->column('revision_number'), 'DESC' )
           ->limit(1);

    my $dbh = $self->_dbh($select);

    my $row = $dbh->selectrow_hashref( $select->sql($dbh), {}, $select->bind_params() );

    return Silk::Model::PageRevision->new( %{ $row }, _from_query => 1 );
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
