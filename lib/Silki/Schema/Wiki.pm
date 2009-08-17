package Silki::Schema::Wiki;

use strict;
use warnings;

use Fey::Literal;
use Fey::Object::Iterator::FromSelect;
use Fey::SQL;
use Silki::Config;
use Silki::Schema;
use Silki::Schema::Domain;
use Silki::Schema::Page;
use Silki::Schema::Permission;
use Silki::Schema::Role;
use Silki::Schema::UserWikiRole;
use Silki::Schema::WikiRolePermission;
use Silki::Types qw( Bool HashRef Int ValidPermissionType );

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( pos_validated_list validated_list );

with 'Silki::Role::Schema::URIMaker';

my $Schema = Silki::Schema->Schema();

has_table( $Schema->table('Wiki') );

has_one( $Schema->table('Domain') );

has_many pages =>
    ( table    => $Schema->table('Page'),
      order_by => [ $Schema->table('Page')->column('title') ],
    );

has permissions =>
    ( is       => 'ro',
      isa      => HashRef[ HashRef[ Bool ] ],
      lazy     => 1,
      builder  => '_build_permissions',
      init_arg => undef,
    );

has revision_count =>
    ( metaclass   => 'FromSelect',
      is          => 'ro',
      isa         => Int,
      select      => __PACKAGE__->_RevisionCountSelect(),
      bind_params => sub { $_[0]->wiki_id() },
    );

class_has _RecentChangesSelect =>
    ( is      => 'ro',
      isa     => 'Fey::SQL::Select',
      lazy    => 1,
      builder => '_BuildRecentChangesSelect',
    );

class_has _DistinctRecentChangesSelect =>
    ( is      => 'ro',
      isa     => 'Fey::SQL::Select',
      lazy    => 1,
      builder => '_BuildDistinctRecentChangesSelect',
    );

class_has _PublicWikiCountSelect =>
    ( is      => 'ro',
      isa     => 'Fey::SQL::Select',
      lazy    => 1,
      builder => '_BuildPublicWikiCountSelect',
    );

class_has _PublicWikiSelect =>
    ( is      => 'ro',
      isa     => 'Fey::SQL::Select',
      lazy    => 1,
      builder => '_BuildPublicWikiSelect',
    );

my $FrontPage = <<'EOF';
Welcome to your new wiki.

A wiki is a set of web pages that can be read and edited by a group of people. You use simple syntax to add things like *italics* and **bold** to the text. Wikis are designed to make linking to other pages easy.

For more information about wikis in general and Silki in particular, see the [[Help]] page.
EOF

my $Help = <<'EOF';
This needs some content.

Link to a [[Wanted Page]].
EOF

sub insert
{
    my $class = shift;
    my %p     = @_;

    my $wiki;

    $class->SchemaClass()->RunInTransaction
        ( sub
          {
              $wiki = $class->SUPER::insert(%p);

              Silki::Schema::Page->insert_with_content
                  ( title          => 'Front Page',
                    content        => $FrontPage,
                    wiki_id        => $wiki->wiki_id(),
                    user_id        => $wiki->user_id(),
                    can_be_renamed => 0,
                  );

              Silki::Schema::Page->insert_with_content
                  ( title          => 'Help',
                    content        => $Help,
                    wiki_id        => $wiki->wiki_id(),
                    user_id        => $wiki->user_id(),
                    can_be_renamed => 0,
                  );
          }
        );

    return $wiki;
}

sub _base_uri_path
{
    my $self = shift;

    return '/wiki/' . $self->short_name();
}

sub add_user
{
    my $self = shift;
    my ( $user, $role ) =
        validated_list( \@_,
                        user => { isa => 'Silki::Schema::User' },
                        role => { isa => 'Silki::Schema::Role',
                                  default => Silki::Schema::Role->Member(),
                                },
                      );

    return if $user->is_system_user();

    Silki::Schema::UserWikiRole->insert( user_id => $user->user_id,
                                         wiki_id => $self->wiki_id(),
                                         role_id => $role->role_id(),
                                       );

    return;
}

sub _build_permissions
{
    my $self = shift;

    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    $select->select( $Schema->table('Role')->column('name'),
                     $Schema->table('Permission')->column('name'),
                   )
           ->from( $Schema->table('Permission'), $Schema->table('WikiRolePermission') )
           ->from( $Schema->table('Role'), $Schema->table('WikiRolePermission') )
           ->where( $Schema->table('WikiRolePermission')->column('wiki_id'),
                    '=', $self->wiki_id() );

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    my %perms;
    for my $row ( @{ $dbh->selectall_arrayref( $select->sql($dbh), {}, $select->bind_params() ) } )
    {
        $perms{ $row->[0] }{ $row->[1] } = 1;
    }

    return \%perms;
}

{
    my %Sets = ( 'public' =>
                     { Guest         => [qw( Read Edit )],
                       Authenticated => [qw( Read Edit )],
                       Member        => [qw( Read Edit Delete Upload )],
                       Admin         => [qw( Read Edit Delete Upload Invite Manage )],
                     },
                 'public-authenticate-to-edit' =>
                     { Guest         => [qw( Read )],
                       Authenticated => [qw( Read Edit )],
                       Member        => [qw( Read Edit Delete Upload )],
                       Admin         => [qw( Read Edit Delete Upload Invite Manage )],
                     },
                 'public-read-only' =>
                     { Guest         => [qw( Read )],
                       Authenticated => [qw( Read )],
                       Member        => [qw( Read Edit Delete Upload )],
                       Admin         => [qw( Read Edit Delete Upload Invite Manage )],
                     },
                 'private' =>
                     { Guest         => [],
                       Authenticated => [],
                       Member        => [qw( Read Edit Delete Upload Invite )],
                       Admin         => [qw( Read Edit Delete Upload Invite Manage )],
                     },
               );

    sub set_permissions
    {
        my $self   = shift;
        my ($type) = pos_validated_list( \@_, { isa => ValidPermissionType } );

        my $set = $Sets{$type};

        my @inserts;
        for my $role_name ( keys %{ $set } )
        {
            my $role = Silki::Schema::Role->$role_name();

            for my $perm_name ( @{ $set->{$role_name} } )
            {
                my $perm = Silki::Schema::Permission->$perm_name();

                push @inserts, { wiki_id       => $self->wiki_id(),
                                 role_id       => $role->role_id(),
                                 permission_id => $perm->permission_id(),
                               };
            }
        }

        Silki::Schema::WikiRolePermission->insert_many(@inserts);
    }
}

sub _RevisionCountSelect
{
    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    my ( $page_t, $page_revision_t ) = $Schema->tables( 'Page', 'PageRevision' );

    my $count = Fey::Literal::Function->new( 'COUNT', $page_revision_t->column('page_id') );

    $select->select($count)
           ->from( $page_t, $page_revision_t )
           ->where( $page_t->column('wiki_id'), '=', Fey::Placeholder->new() );

    return $select;
}

sub revisions
{
    my $self = shift;
    my ( $limit, $offset ) =
        validated_list( \@_,
                        limit  => { isa => Int, optional => 1 },
                        offset => { isa => Int, default => 0 },
                      );

    my $select = $self->_RecentChangesSelect()->clone();
    $select->limit( $limit, $offset );

    return
        Fey::Object::Iterator::FromSelect->new
            ( classes     => [ 'Silki::Schema::Page', 'Silki::Schema::PageRevision' ],
              select      => $select,
              dbh         => Silki::Schema->DBIManager()->source_for_sql($select)->dbh(),
              bind_params => [ $self->wiki_id() ],
            );
}

sub _BuildRecentChangesSelect
{
    my $class = shift;

    my $page_t = $Schema->table('Page');

    my $max_func =
        Fey::Literal::Function->new( 'MAX', $Schema->table('PageRevision')->column('revision_number') );

    my $pages_select = Silki::Schema->SQLFactoryClass()->new_select();
    $pages_select->select( $page_t, $Schema->table('PageRevision') )
                 ->from( $page_t, $Schema->table('PageRevision') )
                 ->where( $page_t->column('wiki_id'), '=', Fey::Placeholder->new() )
                 ->order_by( $Schema->table('PageRevision')->column('creation_datetime'), 'DESC',
                             $Schema->table('Page')->column('title'), 'ASC',
                           );

    return $pages_select;
}

# This gets recently changed pages but only shows each page once, in its most
# recent revision.
sub _BuildDistinctRecentChangesSelect
{
    my $class = shift;

    my $page_t = $Schema->table('Page');

    my $max_func =
        Fey::Literal::Function->new( 'MAX', $Schema->table('PageRevision')->column('revision_number') );

    my $max_revision = Silki::Schema->SQLFactoryClass()->new_select();
    $max_revision->select($max_func)
                 ->from( $Schema->table('PageRevision') )
                 ->where( $Schema->table('PageRevision')->column('page_id'),
                          '=', $page_t->column('page_id') );

    my $pages_select = Silki::Schema->SQLFactoryClass()->new_select();
    $pages_select->select( $page_t, $Schema->table('PageRevision') )
                 ->from( $page_t, $Schema->table('PageRevision') )
                 ->where( $page_t->column('wiki_id'), '=', Fey::Placeholder->new() )
                 ->and( $Schema->table('PageRevision')->column('revision_number'),
                        '=', $max_revision )
                 ->order_by( $Schema->table('PageRevision')->column('creation_datetime'), 'DESC',
                             $Schema->table('Page')->column('title'), 'ASC',
                           );

    return $pages_select;
}

sub PublicWikiCount
{
    my $class = shift;

    my $select = $class->_PublicWikiCountSelect();

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    my $vals = $dbh->selectrow_arrayref( $select->sql($dbh), {}, $select->bind_params() );

    return $vals ? $vals->[0] : 0;
}

sub _BuildPublicWikiCountSelect
{
    my $class  = shift;
    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    my $distinct = Fey::Literal::Term->new( 'DISTINCT ', $class->Table()->column('wiki_id') );
    my $count = Fey::Literal::Function->new( 'COUNT', $distinct );

    $select->select($count);

    $class->_PublicWikiSelectBase($select);

    return $select;
}

sub PublicWikis
{
    my $class = shift;
    my ( $limit, $offset ) =
        validated_list( \@_,
                        limit  => { isa => Int, optional => 1 },
                        offset => { isa => Int, default => 0 },
                      );

    my $select = $class->_PublicWikiSelect()->clone();
    $select->limit( $limit, $offset );

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    return
        Fey::Object::Iterator::FromSelect->new
            ( classes     => 'Silki::Schema::Wiki',
              select      => $select,
              dbh         => $dbh,
              bind_params => [ $select->bind_params() ],
            );
}


sub _BuildPublicWikiSelect
{
    my $class  = shift;

    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    $select->select( $class->Table() )->distinct();
    $class->_PublicWikiSelectBase($select);
    $select->order_by( $class->Table()->column('title') );

    return $select;
}

sub _PublicWikiSelectBase
{
    my $class  = shift;
    my $select = shift;

    my $anon = Silki::Schema::Role->Guest();
    my $read = Silki::Schema::Permission->Read();

    $select->from( $Schema->tables( 'Wiki', 'WikiRolePermission' ) )
           ->where( $Schema->table('WikiRolePermission')->column('role_id'),
                    '=', $anon->role_id() )
           ->and( $Schema->table('WikiRolePermission')->column('permission_id'),
                  '=', $read->permission_id() );

    return;
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();


1;

__END__


