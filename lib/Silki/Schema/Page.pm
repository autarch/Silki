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
use MooseX::ClassAttribute;

with 'Silki::Role::Schema::URIMaker';

my $Schema = Silki::Schema->Schema();

has_policy 'Silki::Schema::Policy';

has_table( $Schema->table('Page') );

has_one( $Schema->table('User') );

has_one( $Schema->table('Wiki') );

has_many revisions =>
    ( table    => $Schema->table('PageRevision'),
      order_by =>
      [ $Schema->table('PageRevision')->column('revision_number'), 'DESC' ],
    );

has_one most_recent_revision =>
    ( table       => $Schema->table('PageRevision'),
      select      => __PACKAGE__->_MostRecentRevisionSelect(),
      bind_params => sub { $_[0]->page_id() },
      handles     => [ qw( content content_as_html ) ],
    );

class_has _PendingPageLinkSelectSQL =>
    ( is      => 'ro',
      isa     => 'Fey::SQL::Select',
      lazy    => 1,
      builder => '_BuildPendingPageLinkSelectSQL',
    );

class_has _PendingPageLinkDeleteSQL =>
    ( is      => 'ro',
      isa     => 'Fey::SQL::Delete',
      lazy    => 1,
      builder => '_BuildPendingPageLinkDeleteSQL',
    );

sub _base_uri_path
{
    my $self = shift;

    return $self->wiki()->_base_uri_path() . '/page/' . $self->uri_path();
}

around insert => sub
{
    my $orig  = shift;
    my $class = shift;

    my $page = $class->$orig(@_);

    my $select = $class->_PendingPageLinkSelectSQL();

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    # XXX - hack but it should work fine
    my $select_sql = $select->sql($dbh) . ' FOR UPDATE';

    my $delete = $class->_PendingPageLinkDeleteSQL();

    my $update_links = sub
    {
        my $links =
            $dbh->selectcol_arrayref( $select_sql,
                                      {},
                                      $page->wiki_id(),
                                      $page->title(),
                                    );

        return unless @{$links};

        $dbh->do( $delete->sql($dbh),
                  {},
                  $page->wiki_id(),
                  $page->title(),
                );

        my @new_links = map { { from_page_id => $_,
                                to_page_id   => $page->page_id(),
                              } } @{ $links };

        Silki::Schema::PageLink->insert_many(@new_links);
    };

    Silki::Schema->RunInTransaction($update_links);

    return $page;
};

sub _BuildPendingPageLinkSelectSQL
{
    my $select = Silki::Schema->SQLFactoryClass()->new_select();
    $select->select( $Schema->table('PendingPageLink')->column('from_page_id') )
           ->from( $Schema->table('PendingPageLink') )
           ->where( $Schema->table('PendingPageLink')->column('to_wiki_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $Schema->table('PendingPageLink')->column('to_page_title'),
                    '=', Fey::Placeholder->new() );

    return $select;
}

sub _BuildPendingPageLinkDeleteSQL
{
    my $delete = Silki::Schema->SQLFactoryClass()->new_delete();
    $delete->delete()
           ->from( $Schema->table('PendingPageLink') )
           ->where( $Schema->table('PendingPageLink')->column('to_wiki_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $Schema->table('PendingPageLink')->column('to_page_title'),
                    '=', Fey::Placeholder->new() );

    return $delete;
}

sub insert_with_content
{
    my $class = shift;
    my %p     = @_;

    my %page_p =
        ( map { $_ => delete $p{$_} }
          grep { exists $p{$_} }
          map { $_->name() }
          $class->Table()->columns()
        );

    $page_p{uri_path} = $class->_title_to_uri_path( $page_p{title} );

    my $page;
    $class->SchemaClass()->RunInTransaction
        ( sub
          {
              $page = $class->insert(%page_p);

              $page->add_revision( %p,
                                   user_id => $page->user_id(),
                                 );
          }
        );

    return $page;
}

sub add_revision
{
    my $self = shift;
    my %p    = @_;

    my $revision = $self->most_recent_revision();
    my $revision_number = $revision ? $revision->revision_number() + 1 : 1;

    $self->_clear_most_recent_revision();

    return
        Silki::Schema::PageRevision->insert
            ( %p,
              revision_number => $revision_number,
              page_id         => $self->page_id(),
            );
}

sub _title_to_uri_path
{
    my $self  = shift;
    my $title = shift;

    # This is the default list of safe characters, except we also escape
    # underscores. This lets us replace escaped spaces (%20) with underscores
    # after URI-escaping, making for much friendlier paths.
    my $escaped = uri_escape_utf8( $title, q{^A-Za-z0-9-.!~*'()"} );

    $escaped =~ s/%20/_/;

    return $escaped;
}

sub _MostRecentRevisionSelect
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
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__
