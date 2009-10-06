package Silki::Schema::Page;

use strict;
use warnings;

use Fey::Object::Iterator::FromSelect;
use Fey::Placeholder;
use List::AllUtils qw( first );
use Silki::Config;
use Silki::Schema::PageRevision;
use Silki::Schema;
use Silki::Schema::File;
use Silki::Schema::Wiki;
use Silki::Types qw( Bool Int );
use URI::Escape qw( uri_escape_utf8 );

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( validated_list pos_validated_list );

with 'Silki::Role::Schema::URIMaker';

my $Schema = Silki::Schema->Schema();

has_policy 'Silki::Schema::Policy';

has_table( $Schema->table('Page') );

has_one( $Schema->table('User') );

has_one wiki => (
    table   => $Schema->table('Wiki'),
    handles => ['domain'],
);

has revision_count => (
    metaclass   => 'FromSelect',
    is          => 'ro',
    isa         => Int,
    select      => __PACKAGE__->_RevisionCountSelect(),
    bind_params => sub { $_[0]->page_id() },
);

class_has _RevisionsSelect => (
    is      => 'ro',
    isa     => 'Fey::SQL::Select',
    lazy    => 1,
    builder => '_BuildRevisionsSelect',
);

has_one most_recent_revision => (
    table       => $Schema->table('PageRevision'),
    select      => __PACKAGE__->_MostRecentRevisionSelect(),
    bind_params => sub { $_[0]->page_id() },
    handles     => {
        content                => 'content',
        last_modified_datetime => 'creation_datetime',
    },
);

has_one first_revision => (
    table       => $Schema->table('PageRevision'),
    select      => __PACKAGE__->_FirstRevisionSelect(),
    bind_params => sub { $_[0]->page_id(), 1 },
    handles     => {
        creation_datetime => 'creation_datetime',
    },
);

has incoming_link_count => (
    metaclass   => 'FromSelect',
    is          => 'ro',
    isa         => Int,
    select      => __PACKAGE__->_IncomingLinkCountSelect(),
    bind_params => sub { $_[0]->page_id() },
);

has_many incoming_links => (
    table       => $Schema->table('Page'),
    select      => __PACKAGE__->_IncomingLinkSelect(),
    bind_params => sub { $_[0]->page_id() },
);

has file_count => (
    metaclass   => 'FromSelect',
    is          => 'ro',
    isa         => Int,
    select      => __PACKAGE__->_FileCountSelect(),
    bind_params => sub { $_[0]->page_id() },
);

has_many files => (
    table       => $Schema->table('File'),
    select      => __PACKAGE__->_FileSelect(),
    bind_params => sub { $_[0]->page_id() },
);

has is_front_page => (
    is       => 'ro',
    isa      => Bool,
    lazy     => 1,
    default  => sub { $_[0]->title() eq 'Front Page' },
    init_arg => undef,
);

class_has _PendingPageLinkSelectSQL => (
    is      => 'ro',
    isa     => 'Fey::SQL::Select',
    lazy    => 1,
    builder => '_BuildPendingPageLinkSelectSQL',
);

class_has _PendingPageLinkDeleteSQL => (
    is      => 'ro',
    isa     => 'Fey::SQL::Delete',
    lazy    => 1,
    builder => '_BuildPendingPageLinkDeleteSQL',
);

class_has _PageFileInsertSQL => (
    is      => 'ro',
    isa     => 'Fey::SQL::Insert',
    lazy    => 1,
    builder => '_BuildPageFileInsertSQL',
);

sub _base_uri_path {
    my $self = shift;

    return $self->wiki()->_base_uri_path() . '/page/' . $self->uri_path();
}

around insert => sub {
    my $orig  = shift;
    my $class = shift;

    my $page = $class->$orig(@_);

    my $select = $class->_PendingPageLinkSelectSQL();

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    # XXX - hack but it should work fine
    my $select_sql = $select->sql($dbh) . ' FOR UPDATE';

    my $delete = $class->_PendingPageLinkDeleteSQL();

    my $update_links = sub {
        my $links = $dbh->selectcol_arrayref(
            $select_sql,
            {},
            $page->wiki_id(),
            $page->title(),
        );

        return unless @{$links};

        $dbh->do(
            $delete->sql($dbh),
            {},
            $page->wiki_id(),
            $page->title(),
        );

        my @new_links
            = map { { from_page_id => $_, to_page_id => $page->page_id(), } }
            @{$links};

        Silki::Schema::PageLink->insert_many(@new_links);
    };

    Silki::Schema->RunInTransaction($update_links);

    return $page;
};

sub _BuildPendingPageLinkSelectSQL {
    my $select = Silki::Schema->SQLFactoryClass()->new_select();
    $select->select(
        $Schema->table('PendingPageLink')->column('from_page_id') )
        ->from( $Schema->table('PendingPageLink') )->where(
        $Schema->table('PendingPageLink')->column('to_wiki_id'),
        '=', Fey::Placeholder->new()
        )->and(
        $Schema->table('PendingPageLink')->column('to_page_title'),
        '=', Fey::Placeholder->new()
        );

    return $select;
}

sub _BuildPendingPageLinkDeleteSQL {
    my $delete = Silki::Schema->SQLFactoryClass()->new_delete();
    $delete->delete()->from( $Schema->table('PendingPageLink') )->where(
        $Schema->table('PendingPageLink')->column('to_wiki_id'),
        '=', Fey::Placeholder->new()
        )->and(
        $Schema->table('PendingPageLink')->column('to_page_title'),
        '=', Fey::Placeholder->new()
        );

    return $delete;
}

sub insert_with_content {
    my $class = shift;
    my %p     = @_;

    my %page_p = (
        map { $_ => delete $p{$_} }
            grep { exists $p{$_} }
            map  { $_->name() } $class->Table()->columns()
    );

    $page_p{uri_path} = $class->_title_to_uri_path( $page_p{title} );

    my $page;
    $class->SchemaClass()->RunInTransaction(
        sub {
            $page = $class->insert(%page_p);

            $page->add_revision(
                %p,
                user_id => $page->user_id(),
            );
        }
    );

    return $page;
}

sub add_revision {
    my $self = shift;
    my %p    = @_;

    my $revision = $self->most_recent_revision();
    my $revision_number = $revision ? $revision->revision_number() + 1 : 1;

    $self->_clear_most_recent_revision();

    return Silki::Schema::PageRevision->insert(
        %p,
        revision_number => $revision_number,
        page_id         => $self->page_id(),
    );
}

sub add_file {
    my $self = shift;
    my ($file) = pos_validated_list( \@_, { isa => 'Silki::Schema::File' } );

    my $insert = $self->_PageFileInsertSQL();

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($insert)->dbh();

    my $last_rev = $self->most_recent_revision();
    my $new_content = $last_rev->content();

    $new_content =~ s/\n*$/\n\n/;
    $new_content .= '[[file:' . $file->file_id() . ']]';
    $new_content .= "\n";

    my $trans = sub {
        $dbh->do(
            $insert->sql($dbh),
            {},
            $self->page_id(),
            $file->file_id(),
        );

        $self->add_revision(
            content => $new_content,
            user_id => $file->user_id(),
        );

    };

    Silki::Schema->RunInTransaction($trans);

    return;
}

sub _title_to_uri_path {
    my $self  = shift;
    my $title = shift;

    # This is the default list of safe characters, except we also escape
    # underscores. This lets us replace escaped spaces (%20) with underscores
    # after URI-escaping, making for much friendlier paths.
    my $escaped = uri_escape_utf8( $title, q{^A-Za-z0-9-.!~*'()"} );

    $escaped =~ s/%20/_/;

    return $escaped;
}

sub _MostRecentRevisionSelect {
    my $self = shift;

    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    $select->select( $Schema->table('PageRevision') )
        ->from( $Schema->table('PageRevision') )->where(
        $Schema->table('PageRevision')->column('page_id'),
        '=', Fey::Placeholder->new()
        )
        ->order_by( $Schema->table('PageRevision')->column('revision_number'),
        'DESC' )->limit(1);

    return $select;
}

sub _FirstRevisionSelect {
    my $self = shift;

    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    $select->select( $Schema->table('PageRevision') )
        ->from( $Schema->table('PageRevision') )->where(
        $Schema->table('PageRevision')->column('page_id'),
        '=', Fey::Placeholder->new()
        )->and(
        $Schema->table('PageRevision')->column('revision_number'),
        '=', Fey::Placeholder->new()
        );

    return $select;
}

sub _IncomingLinkCountSelect {
    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    my $page_link_t = $Schema->table('PageLink');

    my $count = Fey::Literal::Function->new( 'COUNT',
        $page_link_t->column('from_page_id') );

    $select->select($count)->from($page_link_t)
        ->where( $page_link_t->column('to_page_id'), '=',
        Fey::Placeholder->new() );

    return $select;
}

sub _IncomingLinkSelect {
    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    my ( $page_t, $page_link_t ) = $Schema->tables( 'Page', 'PageLink' );

    my ($fk)
        = first { $_->has_column( $page_link_t->column('from_page_id') ) }
    $Schema->foreign_keys_between_tables( $page_t, $page_link_t );

    $select->select($page_t)->from( $page_t, $page_link_t, $fk )
        ->where( $page_link_t->column('to_page_id'), '=',
        Fey::Placeholder->new() )->order_by( $page_t->column('title') );

    return $select;
}

sub _FileCountSelect {
    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    my $page_file_t = $Schema->table('PageFile');
    my $count = Fey::Literal::Function->new( 'COUNT',
        $page_file_t->column('file_id') );

    $select->select($count)
           ->from($page_file_t)
           ->where( $page_file_t->column('page_id'), '=',
                    Fey::Placeholder->new() );

    return $select;
}

sub _FileSelect {
    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    my ( $page_file_t, $file_t ) = $Schema->tables( 'PageFile', 'File' );

    $select->select($file_t)
           ->from( $page_file_t, $file_t )
           ->where( $page_file_t->column('page_id'), '=',
                    Fey::Placeholder->new() )
           ->order_by( $file_t->column('file_name') );

    return $select;
}

sub _RevisionCountSelect {
    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    my $page_revision_t = $Schema->table('PageRevision');

    my $count = Fey::Literal::Function->new( 'COUNT',
        $page_revision_t->column('page_id') );

    $select->select($count)->from($page_revision_t)
        ->where( $page_revision_t->column('page_id'), '=',
        Fey::Placeholder->new() );

    return $select;
}

sub _BuildPageFileInsertSQL {
    my $insert = Silki::Schema->SQLFactoryClass()->new_insert();

    $insert->into( $Schema->table('PageFile') )
           ->values( page_id => Fey::Placeholder->new(),
                     file_id => Fey::Placeholder->new() );

    return $insert;
}

sub revisions {
    my $self = shift;
    my ( $limit, $offset ) = validated_list(
        \@_,
        limit  => { isa => Int, optional => 1 },
        offset => { isa => Int, default  => 0 },
    );

    my $select = $self->_RevisionsSelect()->clone();
    $select->limit( $limit, $offset );

    return Fey::Object::Iterator::FromSelect->new(
        classes => ['Silki::Schema::PageRevision'],
        select  => $select,
        dbh => Silki::Schema->DBIManager()->source_for_sql($select)->dbh(),
        bind_params => [ $self->page_id() ],
    );
}

sub _BuildRevisionsSelect {
    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    my $page_revision_t = $Schema->table('PageRevision');

    $select->select($page_revision_t)->from($page_revision_t)
        ->where( $page_revision_t->column('page_id'), '=',
        Fey::Placeholder->new() )
        ->order_by( $page_revision_t->column('revision_number'), 'DESC' );

    return $select;
}

no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__
