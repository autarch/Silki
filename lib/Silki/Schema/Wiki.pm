package Silki::Schema::Wiki;

use strict;
use warnings;

use Data::Dumper qw( Dumper );
use Fey::Literal;
use Fey::Object::Iterator::FromSelect;
use Fey::SQL;
use List::AllUtils qw( uniq );
use Silki::Config;
use Silki::Schema;
use Silki::Schema::Domain;
use Silki::Schema::File;
use Silki::Schema::Page;
use Silki::Schema::Permission;
use Silki::Schema::Role;
use Silki::Schema::UserWikiRole;
use Silki::Schema::WantedPage;
use Silki::Schema::WikiRolePermission;
use Silki::Types qw( Bool HashRef Int Str ValidPermissionType );

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( pos_validated_list validated_list );

with 'Silki::Role::Schema::URIMaker';

my $Schema = Silki::Schema->Schema();

has_table( $Schema->table('Wiki') );

has_one( $Schema->table('Domain') );

has_many pages => (
    table    => $Schema->table('Page'),
    order_by => [ $Schema->table('Page')->column('title') ],
);

has permissions => (
    is       => 'ro',
    isa      => HashRef[ HashRef[Bool] ],
    lazy     => 1,
    builder  => '_build_permissions',
    init_arg => undef,
    clearer  => '_clear_permissions',
);

has permissions_name => (
    is       => 'ro',
    isa      => Str,
    lazy     => 1,
    builder  => '_build_permissions_name',
    init_arg => undef,
    clearer  => '_clear_permissions_name',
);

query revision_count => (
    select      => __PACKAGE__->_RevisionCountSelect(),
    bind_params => sub { $_[0]->wiki_id() },
);

has front_page_title => (
    is       => 'ro',
    isa      => Str,
    lazy     => 1,
    init_arg => 1,
    builder  => '_build_front_page_title',
);

query orphaned_page_count => (
    select      => __PACKAGE__->_OrphanedPageCountSelect(),
    bind_params => sub { $_[0]->wiki_id(), $_[0]->front_page_title() },
);

query wanted_page_count => (
    select      => __PACKAGE__->_WantedPageCountSelect(),
    bind_params => sub { $_[0]->wiki_id() },
);

query file_count => (
    select      => __PACKAGE__->_FileCountSelect(),
    bind_params => sub { $_[0]->wiki_id() },
);

class_has _RecentChangesSelect => (
    is      => 'ro',
    isa     => 'Fey::SQL::Select',
    lazy    => 1,
    builder => '_BuildRecentChangesSelect',
);

class_has _DistinctRecentChangesSelect => (
    is      => 'ro',
    isa     => 'Fey::SQL::Select',
    lazy    => 1,
    builder => '_BuildDistinctRecentChangesSelect',
);

class_has _FilesSelect => (
    is      => 'ro',
    isa     => 'Fey::SQL::Select',
    lazy    => 1,
    builder => '_BuildFilesSelect',
);

class_has _OrphanedPagesSelect => (
    is      => 'ro',
    isa     => 'Fey::SQL::Select',
    lazy    => 1,
    builder => '_BuildOrphanedPagesSelect',
);

class_has _WantedPagesSelect => (
    is      => 'ro',
    isa     => 'Fey::SQL::Select',
    lazy    => 1,
    builder => '_BuildWantedPagesSelect',
);

class_has _MembersSelect => (
    is      => 'ro',
    isa     => 'Fey::SQL::Select',
    lazy    => 1,
    builder => '_BuildMembersSelect',
);

class_has _PublicWikiCountSelect => (
    is      => 'ro',
    isa     => 'Fey::SQL::Select',
    lazy    => 1,
    builder => '_BuildPublicWikiCountSelect',
);

class_has _PublicWikiSelect => (
    is      => 'ro',
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

sub insert {
    my $class = shift;
    my %p     = @_;

    my $wiki;

    $class->SchemaClass()->RunInTransaction(
        sub {
            $wiki = $class->SUPER::insert(%p);

            Silki::Schema::Page->insert_with_content(
                title          => 'Front Page',
                content        => $FrontPage,
                wiki_id        => $wiki->wiki_id(),
                user_id        => $wiki->user_id(),
                can_be_renamed => 0,
            );

            Silki::Schema::Page->insert_with_content(
                title          => 'Help',
                content        => $Help,
                wiki_id        => $wiki->wiki_id(),
                user_id        => $wiki->user_id(),
                can_be_renamed => 0,
            );
        }
    );

    return $wiki;
}

sub _base_uri_path {
    my $self = shift;

    return '/wiki/' . $self->short_name();
}

sub add_user {
    my $self = shift;
    my ( $user, $role ) = validated_list(
        \@_,
        user => { isa => 'Silki::Schema::User' },
        role => {
            isa     => 'Silki::Schema::Role',
            default => Silki::Schema::Role->Member(),
        },
    );

    return if $user->is_system_user();

    return if $role->name() eq 'Guest' || $role->name() eq 'Authenticated';

    my $uwr = Silki::Schema::UserWikiRole->new(
        user_id => $user->user_id(),
        wiki_id => $self->wiki_id(),
    );

    if ($uwr) {
        $uwr->update( role_id => $role->role_id() );
    }
    else {
        Silki::Schema::UserWikiRole->insert(
            user_id => $user->user_id(),
            wiki_id => $self->wiki_id(),
            role_id => $role->role_id(),
        );
    }

    return;
}

sub remove_user {
    my $self = shift;
    my ($user) = validated_list(
        \@_,
        user => { isa => 'Silki::Schema::User' },
    );

    return if $user->is_system_user();

    my $uwr = Silki::Schema::UserWikiRole->new(
        user_id => $user->user_id(),
        wiki_id => $self->wiki_id(),
    );

    $uwr->delete() if $uwr;

    return;
}

sub _build_permissions {
    my $self = shift;

    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    $select->select(
        $Schema->table('Role')->column('name'),
        $Schema->table('Permission')->column('name'),
        )
        ->from( $Schema->table('Permission'),
        $Schema->table('WikiRolePermission') )
        ->from( $Schema->table('Role'), $Schema->table('WikiRolePermission') )
        ->where(
        $Schema->table('WikiRolePermission')->column('wiki_id'),
        '=', $self->wiki_id()
        );

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    my %perms;
    for my $row (
        @{
            $dbh->selectall_arrayref(
                $select->sql($dbh), {}, $select->bind_params()
            )
        }
        ) {
        $perms{ $row->[0] }{ $row->[1] } = 1;
    }

    return \%perms;
}

{
    my %Sets = (
        'public' => {
            Guest         => [qw( Read Edit )],
            Authenticated => [qw( Read Edit )],
            Member        => [qw( Read Edit Delete Upload )],
            Admin         => [qw( Read Edit Delete Upload Invite Manage )],
        },
        'public-authenticate-to-edit' => {
            Guest         => [qw( Read )],
            Authenticated => [qw( Read Edit )],
            Member        => [qw( Read Edit Delete Upload )],
            Admin         => [qw( Read Edit Delete Upload Invite Manage )],
        },
        'public-read-only' => {
            Guest         => [qw( Read )],
            Authenticated => [qw( Read )],
            Member        => [qw( Read Edit Delete Upload )],
            Admin         => [qw( Read Edit Delete Upload Invite Manage )],
        },
        'private' => {
            Guest         => [],
            Authenticated => [],
            Member        => [qw( Read Edit Delete Upload )],
            Admin         => [qw( Read Edit Delete Upload Invite Manage )],
        },
    );

    my $Delete = Silki::Schema->SQLFactoryClass()->new_delete();
    $Delete->from( $Schema->table('WikiRolePermission') )
           ->where(
            $Schema->table('WikiRolePermission')->column('wiki_id'),
            '=',
            Fey::Placeholder->new()
        );

    sub set_permissions {
        my $self = shift;
        my ($type)
            = pos_validated_list( \@_, { isa => ValidPermissionType } );

        my $set = $Sets{$type};

        my @inserts;
        for my $role_name ( keys %{$set} ) {
            my $role = Silki::Schema::Role->$role_name();

            for my $perm_name ( @{ $set->{$role_name} } ) {
                my $perm = Silki::Schema::Permission->$perm_name();

                push @inserts,
                    {
                    wiki_id       => $self->wiki_id(),
                    role_id       => $role->role_id(),
                    permission_id => $perm->permission_id(),
                    };
            }
        }

        my $dbh = Silki::Schema->DBIManager()->source_for_sql($Delete)->dbh();
        my $trans = sub {
            $dbh->do( $Delete->sql($dbh), {}, $self->wiki_id() );
            Silki::Schema::WikiRolePermission->insert_many(@inserts);
        };

        Silki::Schema->RunInTransaction($trans);

        $self->_clear_permissions();
        $self->_clear_permissions_name();

        return;
    }

    my %SetsAsHashes;
    for my $name ( keys %Sets ) {
        for my $role ( keys %{ $Sets{$name} } ) {
            next unless @{ $Sets{$name}{$role} };
            $SetsAsHashes{$name}{$role}
                = { map { $_ => 1 } @{ $Sets{$name}{$role} } };
        }
    }

    sub _build_permissions_name {
        my $self = shift;

        local $Data::Dumper::Sortkeys = 1;
        my $perms = Dumper( $self->permissions() );

        for my $name ( keys %SetsAsHashes ) {
            return $name if $perms eq Dumper( $SetsAsHashes{$name} );
        }

        return 'custom';
    }
}

sub _build_front_page_title {
    my $self = shift;

    # XXX - needs i18n
    return 'Front Page';
}

sub _RevisionCountSelect {
    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    my ( $page_t, $page_revision_t )
        = $Schema->tables( 'Page', 'PageRevision' );

    my $count = Fey::Literal::Function->new( 'COUNT',
        $page_revision_t->column('page_id') );

    $select->select($count)->from( $page_t, $page_revision_t )
        ->where( $page_t->column('wiki_id'), '=', Fey::Placeholder->new() );

    return $select;
}

sub revisions {
    my $self = shift;
    my ( $limit, $offset ) = validated_list(
        \@_,
        limit  => { isa => Int, optional => 1 },
        offset => { isa => Int, default  => 0 },
    );

    my $select = $self->_RecentChangesSelect()->clone();
    $select->limit( $limit, $offset );

    return Fey::Object::Iterator::FromSelect->new(
        classes => [ 'Silki::Schema::Page', 'Silki::Schema::PageRevision' ],
        select  => $select,
        dbh => Silki::Schema->DBIManager()->source_for_sql($select)->dbh(),
        bind_params => [ $self->wiki_id() ],
    );
}

sub _BuildRecentChangesSelect {
    my $class = shift;

    my $page_t = $Schema->table('Page');

    my $pages_select = Silki::Schema->SQLFactoryClass()->new_select();
    $pages_select->select( $page_t, $Schema->table('PageRevision') )
        ->from( $page_t, $Schema->table('PageRevision') )
        ->where( $page_t->column('wiki_id'), '=', Fey::Placeholder->new() )
        ->order_by(
            $Schema->table('PageRevision')->column('creation_datetime'), 'DESC',
            $Schema->table('Page')->column('title'),                     'ASC',
        );

    return $pages_select;
}

# This gets recently changed pages but only shows each page once, in its most
# recent revision.
sub _BuildDistinctRecentChangesSelect {
    my $class = shift;

    my $page_t = $Schema->table('Page');

    my $max_func = Fey::Literal::Function->new( 'MAX',
        $Schema->table('PageRevision')->column('revision_number') );

    my $max_revision = Silki::Schema->SQLFactoryClass()->new_select();
    $max_revision
        ->select($max_func)
        ->from( $Schema->table('PageRevision') )
        ->where(
            $Schema->table('PageRevision')->column('page_id'),
            '=', $page_t->column('page_id')
        );

    my $pages_select = Silki::Schema->SQLFactoryClass()->new_select();
    $pages_select
        ->select( $page_t, $Schema->table('PageRevision') )
        ->from( $page_t, $Schema->table('PageRevision') )
        ->where( $page_t->column('wiki_id'), '=', Fey::Placeholder->new() )
        ->and(
            $Schema->table('PageRevision')->column('revision_number'),
            '=', $max_revision
        )->order_by(
            $Schema->table('PageRevision')->column('creation_datetime'), 'DESC',
            $page_t->column('title'),                                    'ASC',
        );

    return $pages_select;
}

sub orphaned_pages {
    my $self = shift;
    my ( $limit, $offset ) = validated_list(
        \@_,
        limit  => { isa => Int, optional => 1 },
        offset => { isa => Int, default  => 0 },
    );

    my $select = $self->_OrphanedPagesSelect()->clone();
    $select->limit( $limit, $offset );

    return Fey::Object::Iterator::FromSelect->new(
        classes => [ 'Silki::Schema::Page', 'Silki::Schema::PageRevision' ],
        select  => $select,
        dbh => Silki::Schema->DBIManager()->source_for_sql($select)->dbh(),
        bind_params => [ $self->wiki_id(), $self->front_page_title() ],
    );
}

sub _OrphanedPageCountSelect {
    my $class = shift;

    my $page_link_t = $Schema->table('PageLink');

    my $linked_pages = Silki::Schema->SQLFactoryClass()->new_select();
    $linked_pages
        ->select( $page_link_t->column('to_page_id') )
        ->from( $page_link_t );

    my $page_t = $Schema->table('Page');

    my $count = Fey::Literal::Function->new(
        'COUNT',
        $page_t->column('page_id')
    );

    my $pages_select = Silki::Schema->SQLFactoryClass()->new_select();
    $pages_select
        ->select($count)
        ->from($page_t)
        ->where( $page_t->column('wiki_id'), '=', Fey::Placeholder->new() )
        ->and( $page_t->column( 'title' ), '!=', Fey::Placeholder->new() )
        ->and( $page_t->column('page_id'), 'NOT IN', $linked_pages );
}

sub _BuildOrphanedPagesSelect {
    my $class = shift;

    my $page_link_t = $Schema->table('PageLink');

    my $linked_pages = Silki::Schema->SQLFactoryClass()->new_select();
    $linked_pages
        ->select( $page_link_t->column('to_page_id') )
        ->from( $page_link_t );

    my $page_t = $Schema->table('Page');

    my $pages_select = Silki::Schema->SQLFactoryClass()->new_select();
    $pages_select
        ->select($page_t)
        ->from($page_t)
        ->where( $page_t->column('wiki_id'), '=', Fey::Placeholder->new() )
        ->and( $page_t->column( 'title' ), '!=', Fey::Placeholder->new() )
        ->and( $page_t->column('page_id'), 'NOT IN', $linked_pages )
        ->order_by(
            $page_t->column('title'), 'ASC',
        );

}

sub _WantedPageCountSelect {
    my $class = shift;

    my $pending_page_link_t = $Schema->table('PendingPageLink');

    my $distinct = Fey::Literal::Term->new(
        'DISTINCT ',
        $pending_page_link_t->column('to_page_title')
    );
    my $count = Fey::Literal::Function->new( 'COUNT', $distinct );

    my $wanted_select = Silki::Schema->SQLFactoryClass()->new_select();

    $wanted_select
        ->select($count)
        ->from($pending_page_link_t)
        ->where(
            $pending_page_link_t->column('to_wiki_id'), '=',
            Fey::Placeholder->new()
        );
}

sub wanted_pages {
    my $self = shift;
    my ( $limit, $offset ) = validated_list(
        \@_,
        limit  => { isa => Int, optional => 1 },
        offset => { isa => Int, default  => 0 },
    );

    my $select = $self->_WantedPagesSelect()->clone();
    $select->limit( $limit, $offset );

    return Fey::Object::Iterator::FromSelect->new(
        classes => ['Silki::Schema::WantedPage'],
        select  => $select,
        dbh => Silki::Schema->DBIManager()->source_for_sql($select)->dbh(),
        bind_params   => [ $self->wiki_id() ],
        attribute_map => {
            0 => {
                class     => 'Silki::Schema::WantedPage',
                attribute => 'title',
            },
            1 => {
                class     => 'Silki::Schema::WantedPage',
                attribute => 'wiki_id',
            },
            2 => {
                class     => 'Silki::Schema::WantedPage',
                attribute => 'wanted_count',
            },
        },
    );
}

sub _BuildWantedPagesSelect {
    my $class = shift;

    my $pending_page_link_t = $Schema->table('PendingPageLink');

    my $count = Fey::Literal::Function->new(
        'COUNT',
        $pending_page_link_t->column('from_page_id')
    );

    my $wanted_select = Silki::Schema->SQLFactoryClass()->new_select();
    $wanted_select
        ->select( $pending_page_link_t->columns( 'to_page_title', 'to_wiki_id' ), $count )
        ->from( $pending_page_link_t )
        ->where( $pending_page_link_t->column('to_wiki_id'), '=', Fey::Placeholder->new() )
        ->group_by( $pending_page_link_t->columns( 'to_page_title', 'to_wiki_id' ) )
        ->order_by(
            $count, 'DESC',
            $pending_page_link_t->column('to_page_title'), 'ASC',
        );

    return $wanted_select;
}

sub _FileCountSelect {
    my $class = shift;

    my $file_t = $Schema->table('File');

    my $count
        = Fey::Literal::Function->new( 'COUNT', $file_t->column('file_id') );

    my $file_count_select = Silki::Schema->SQLFactoryClass()->new_select();
    $file_count_select
        ->select($count)
        ->from($file_t)
        ->where( $file_t->column('wiki_id'), '=', Fey::Placeholder->new() );

    return $file_count_select;
}

sub files {
    my $self = shift;
    my ( $limit, $offset ) = validated_list(
        \@_,
        limit  => { isa => Int, optional => 1 },
        offset => { isa => Int, default  => 0 },
    );

    my $select = $self->_FilesSelect()->clone();
    $select->limit( $limit, $offset );

    return Fey::Object::Iterator::FromSelect->new(
        classes => ['Silki::Schema::File'],
        select  => $select,
        dbh => Silki::Schema->DBIManager()->source_for_sql($select)->dbh(),
        bind_params   => [ $self->wiki_id() ],
    );
}

sub _BuildFilesSelect {
    my $class = shift;

    my $file_t = $Schema->table('File');

    my $files_select = Silki::Schema->SQLFactoryClass()->new_select();
    $files_select
        ->select($file_t)
        ->from($file_t)
        ->where( $file_t->column('wiki_id'), '=', Fey::Placeholder->new() )
        ->order_by( $file_t->column('file_name'), 'ASC' );

    return $files_select;
}

sub members {
    my $self = shift;
    my ( $limit, $offset ) = validated_list(
        \@_,
        limit  => { isa => Int, optional => 1 },
        offset => { isa => Int, default  => 0 },
    );

    my $select = $self->_MembersSelect()->clone();
    $select->limit( $limit, $offset );

    return Fey::Object::Iterator::FromSelect->new(
        classes => [ 'Silki::Schema::User', 'Silki::Schema::Role' ],
        select  => $select,
        dbh => Silki::Schema->DBIManager()->source_for_sql($select)->dbh(),
        bind_params => [ $self->wiki_id() ],
    );
}

sub _BuildMembersSelect {
    my $class = shift;

    my $user_t = $Schema->table('User');
    my $uwr_t  = $Schema->table('UserWikiRole');
    my $role_t  = $Schema->table('Role');

    my $members_select = Silki::Schema->SQLFactoryClass()->new_select();
    $members_select
        ->select( $user_t, $role_t )
        ->from( $user_t, $uwr_t )
        ->from( $uwr_t, $role_t )
        ->where( $uwr_t->column('wiki_id'), '=', Fey::Placeholder->new() )
        ->order_by( $role_t->column('name'), 'ASC',
                    $user_t->column('display_name'), 'ASC',
                    $user_t->column('email_address'), 'ASC',
                  );

    return $members_select;
}

# This is a rather complicated query. The end result is something like this ..
#
# SELECT
#   *,
#   TS_HEADLINE(title || E'\n' || content, "page") AS "headline"
# FROM
#  (
#     SELECT
#       "Page"."is_archived",
#       "Page"."page_id",
#       ...,
#       "PageRevision"."comment",
#       "PageRevision"."creation_datetime",
#       ...,
#       TS_RANK("Page"."ts_text", "page") AS "rank"
#     FROM
#      "Page" JOIN "PageRevision" ON ("PageRevision"."page_id" = "Page"."page_id")
#     WHERE
#      "Page"."ts_text" @@ ?
#       AND
#      "Page"."wiki_id" = ?
#       AND
#      "PageRevision"."revision_number" =
#          ( SELECT
#              MAX("PageRevision"."revision_number") AS "FUNCTION0"
#            FROM
#              "PageRevision"
#            WHERE
#              "PageRevision"."page_id" = "Page"."page_id" )
#     ORDER BY
#       "rank" DESC, "Page"."title" ASC
#     OFFSET 0
#  )
# AS "SUBSELECT0"
#
# Part of the reason for the complication is that we want to generate the
# headline (TS_HEADLINE) only after applying the OFFSET clause. If we don't do
# this, then we generate the headline for every match, regardless of how many
# are being displayed. See
# http://www.postgresql.org/docs/8.3/static/textsearch-controls.html#TEXTSEARCH-HEADLINE
# for details.
#
# The innermost select clause in on PageRevision.revision_number ensures that
# we only retrieve the most recent revision for a page.

sub text_search {
    my $self = shift;
    my ( $query, $limit, $offset ) = validated_list(
        \@_,
        query  => { isa => Str },
        limit  => { isa => Int, optional => 1 },
        offset => { isa => Int, default  => 0 },
    );

    my $page_t = $Schema->table('Page');
    my $page_revision_t = $Schema->table('PageRevision');
    my $pst_t = $Schema->table('PageSearchableText');

    my $max_func = Fey::Literal::Function->new( 'MAX',
        $Schema->table('PageRevision')->column('revision_number') );

    my $max_revision = Silki::Schema->SQLFactoryClass()->new_select();
    $max_revision
        ->select($max_func)
        ->from( $Schema->table('PageRevision') )
        ->where( $Schema->table('PageRevision')->column('page_id'),
                 '=', $page_t->column('page_id')
               );

    my $rank = Fey::Literal::Function->new(
        'TS_RANK',
        $pst_t->column('ts_text'),
        $query,
    );

    $rank->set_alias_name('rank');

    my $search_select = Silki::Schema->SQLFactoryClass()->new_select();

    $search_select->select( $page_t, $page_revision_t, $rank )
           ->from( $page_t, $page_revision_t )
           ->from( $page_t, $pst_t )
           ->where( $pst_t->column('ts_text'), '@@', Fey::Placeholder->new() )
           ->and( $page_t->column('wiki_id'), '=', Fey::Placeholder->new() )
           ->and( $page_revision_t->column('revision_number'),
                  '=', $max_revision )
           ->order_by( $rank, 'DESC',
                       $page_t->column('title'), 'ASC' );
    $search_select->limit( $limit, $offset );

    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    my $headline = Fey::Literal::Function->new(
        'TS_HEADLINE',
        Fey::Literal::Term->new( q{title || E'\n' || content}, ),
        $query
    );
    $headline->set_alias_name('headline');

    my $star = Fey::Literal::Term->new('*');
    $star->set_can_have_alias(0);

    $select->select( $star, $headline )
           ->from($search_select);

    my $x = 0;
    my %attribute_map;

    # This matches the order of the columns in the $search_select defined
    # above.
    for my $col_name ( sort map { $_->name() } $page_t->columns() ) {
        $attribute_map{ $x++ } = {
            class     => 'Silki::Schema::Page',
            attribute => $col_name,
        };
    }

    for my $col_name ( sort map { $_->name() } $page_revision_t->columns() ) {
        $attribute_map{ $x++ } = {
            class     => 'Silki::Schema::PageRevision',
            attribute => $col_name,
        };
    }

    return Fey::Object::Iterator::FromSelect->new(
        classes => [ 'Silki::Schema::Page', 'Silki::Schema::PageRevision' ],
        select  => $select,
        dbh => Silki::Schema->DBIManager()->source_for_sql($select)->dbh(),
        bind_params   => [ $query, $self->wiki_id() ],
        attribute_map => \%attribute_map,
    );
}

sub PublicWikiCount {
    my $class = shift;

    my $select = $class->_PublicWikiCountSelect();

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    my $vals = $dbh->selectrow_arrayref( $select->sql($dbh), {},
        $select->bind_params() );

    return $vals ? $vals->[0] : 0;
}

sub PublicWikis {
    my $class = shift;
    my ( $limit, $offset ) = validated_list(
        \@_,
        limit  => { isa => Int, optional => 1 },
        offset => { isa => Int, default  => 0 },
    );

    my $select = $class->_PublicWikiSelect()->clone();
    $select->limit( $limit, $offset );

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    return Fey::Object::Iterator::FromSelect->new(
        classes     => 'Silki::Schema::Wiki',
        select      => $select,
        dbh         => $dbh,
        bind_params => [ $select->bind_params() ],
    );
}

{
    my $guest = Silki::Schema::Role->Guest();
    my $read  = Silki::Schema::Permission->Read();

    my ( $wiki_t, $wrp_t ) = $Schema->tables( 'Wiki', 'WikiRolePermission' );

    my $base = Silki::Schema->SQLFactoryClass()->new_select();

    $base->from( $wiki_t, $wrp_t )
         ->where( $wrp_t->column('role_id'), '=', $guest->role_id() )
        ->and( $wrp_t->column('permission_id'), '=', $read->permission_id() );

    sub _BuildPublicWikiCountSelect {
        my $class = shift;

        my $select = $base->clone();

        my $distinct = Fey::Literal::Term->new(
            'DISTINCT ',
            $wiki_t->column('wiki_id')
        );
        my $count = Fey::Literal::Function->new( 'COUNT', $distinct );

        $select->select($count);

        return $select;
    }

    sub _BuildPublicWikiSelect {
        my $class = shift;

        my $select = $base->clone();

        $select->select($wiki_t)
               ->distinct()
               ->order_by( $wiki_t->column('title') );

        return $select;
    }
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__


