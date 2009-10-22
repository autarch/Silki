package Silki::Controller::Wiki;

use strict;
use warnings;

use Data::Page;
use Data::Page::FlickrLike;
use Email::Address;
use File::Basename qw( dirname );
use File::MimeInfo qw( mimetype );
use List::AllUtils qw( all uniq );
use Path::Class ();
use Silki::Config;
use Silki::Formatter::HTMLToWiki;
use Silki::I18N qw( loc );
use Silki::Schema::File;
use Silki::Schema::Page;
use Silki::Schema::Wiki;
use Silki::Util qw( string_is_empty );

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

with 'Silki::Role::Controller::User';

sub _set_wiki : Chained('/') : PathPart('wiki') : CaptureArgs(1) {
    my $self      = shift;
    my $c         = shift;
    my $wiki_name = shift;

    my $wiki = Silki::Schema::Wiki->new( short_name => $wiki_name );

    $c->redirect_and_detach( $c->domain()->uri( with_host => 1 ) )
        unless $wiki;

    $self->_require_permission_for_wiki( $c, $wiki );

    $c->add_tab($_)
        for (
        {
            uri     => $wiki->uri(),
            label   => $wiki->title(),
            tooltip => loc( '%1 overview', $wiki->title() ),
            id      => 'dashboard',
        },
        {
            uri     => $wiki->uri( view => 'recent' ),
            label   => loc('Recent Changes'),
            tooltip => loc('Recent activity in this wiki'),
        },
        );

    $c->stash()->{wiki} = $wiki;
}

sub no_page : Chained('_set_wiki') : PathPart('') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub no_page_GET_html {
    my $self = shift;
    my $c    = shift;

    my $uri = $c->stash()->{wiki}->uri( view => 'dashboard' );

    $c->redirect_and_detach($uri);
}

sub dashboard : Chained('_set_wiki') : PathPart('dashboard') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $c->tab_by_id('dashboard')->set_is_selected(1);

    $c->stash()->{template} = '/wiki/dashboard';
}

sub recent : Chained('_set_wiki') : PathPart('recent') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $c->tab_by_id( loc('Recent Changes') )->set_is_selected(1);

    my $wiki = $c->stash()->{wiki};

    my $limit    = 50;
    my $page_num = $c->request()->params()->{page} || 1;
    my $offset   = $limit * ( $page_num - 1 );

    my $pager = Data::Page->new();
    $pager->total_entries( $wiki->revision_count() );
    $pager->entries_per_page($limit);
    $pager->current_page($page_num);

    $c->stash()->{pager} = $pager;

    $c->stash()->{pages} = $wiki->revisions(
        limit  => $limit,
        offset => $offset,
    );

    $c->stash()->{template} = '/wiki/recent';
}

sub attachments : Chained('_set_wiki') : PathPart('attachments') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{file_count} = $c->stash()->{wiki}->file_count();
    $c->stash()->{files} = $c->stash()->{wiki}->files();

    $c->stash()->{template} = '/wiki/attachments';
}

sub file_collection : Chained('_set_wiki') : PathPart('file') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub file_collection_POST {
    my $self = shift;
    my $c    = shift;

    $self->_require_permission_for_wiki( $c, $c->stash()->{wiki}, 'Upload' );

    my $upload = $c->request()->upload('file');

    $self->_handle_upload(
        $c,
        $upload,
        $c->stash()->{wiki}->uri( view => 'attachments' ),
    );

    $c->session_object()->add_message( loc('The file has been uploaded.' ) );
    $c->redirect_and_detach( $c->stash()->{wiki}->uri( view => 'attachments' ) );
}

sub _handle_upload {
    my $self   = shift;
    my $c      = shift;
    my $upload = shift;
    my $on_error = shift;

    unless ($upload) {
        $c->redirect_with_error(
            error => loc('You did not select a file to upload.'),
            uri   => $on_error,
        );
    }

    if ( $upload->size() > Silki::Config->new()->max_upload_size() ) {
        $c->redirect_with_error(
            error => loc('The file you uploaded was too large.'),
            uri   => $on_error,
        );
    }

    # Copied the logic from Catalyst::Request::Upload without the last step of
    # removing most characters.
    my $basename = $upload->filename;
    $basename =~ s|\\|/|g;
    $basename = ( File::Spec::Unix->splitpath($basename) )[2];

    my $file;
    Silki::Schema->RunInTransaction(
        sub {
            $file = Silki::Schema::File->insert(
                file_name => $basename,
                mime_type => mimetype( $upload->tempname() ),
                file_size => $upload->size(),
                contents  => do { my $fh = $upload->fh(); local $/; <$fh> },
                user_id   => $c->user()->user_id(),
                wiki_id   => $c->stash()->{wiki}->wiki_id(),
            );

            $c->stash()->{page}->add_file($file)
                if $c->stash()->{page};
        }
    );
}

sub orphans : Chained('_set_wiki') : PathPart('orphans') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $wiki = $c->stash()->{wiki};

    $c->stash()->{orphan_count} = $wiki->orphaned_page_count();
    $c->stash()->{orphans} = $wiki->orphaned_pages();
}

sub wanted : Chained('_set_wiki') : PathPart('wanted') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $wiki = $c->stash()->{wiki};

    $c->stash()->{wanted_count} = $wiki->wanted_page_count();
    $c->stash()->{wanted} = $wiki->wanted_pages();
}

sub settings : Chained('_set_wiki') : PathPart('settings') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_permission_for_wiki( $c, $c->stash()->{wiki}, 'Manage' );

    $c->stash()->{template} = '/wiki/settings';
}

sub permissions_form : Chained('_set_wiki') : PathPart('permissions_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_permission_for_wiki( $c, $c->stash()->{wiki}, 'Manage' );

    $c->stash()->{template} = '/wiki/permissions_form';
}

sub permissions : Chained('_set_wiki') : PathPart('permissions') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub permissions_PUT {
    my $self = shift;
    my $c    = shift;

    my $wiki = $c->stash()->{wiki};

    $self->_require_permission_for_wiki( $c, $wiki, 'Manage' );

    my $perms = $c->request()->params()->{permissions};

    $wiki->set_permissions($perms);

    my $perm_loc = loc($perms);
    $c->session_object()->add_message( loc('Permissions for this wiki have been set to %1', $perm_loc ) );

    $c->redirect_and_detach( $wiki->uri( view => 'permissions_form' ) );
}

sub members_form : Chained('_set_wiki') : PathPart('members_form') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_require_permission_for_wiki( $c, $c->stash()->{wiki}, 'Manage' );

    $c->stash()->{members} = $c->stash()->{wiki}->members();

    $c->stash()->{template} = '/wiki/members_form';
}

sub members : Chained('_set_wiki') : PathPart('members') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub members_PUT {
    my $self = shift;
    my $c    = shift;

    my $wiki = $c->stash()->{wiki};

    $self->_require_permission_for_wiki( $c, $wiki, 'Manage' );

    $self->_process_existing_member_changes($c);
    $self->_process_new_members($c);

    $c->redirect_and_detach( $wiki->uri( view => 'members_form' ) );
}

sub _process_existing_member_changes {
    my $self = shift;
    my $c    = shift;

    my $wiki = $c->stash()->{wiki};

    for my $user_id ( $c->request()->param('members') ) {
        next if $user_id == $c->user()->user_id();

        my $role_id = $c->request()->params()->{ 'role_for_' . $user_id };

        my $user = Silki::Schema::User->new( user_id => $user_id );
        if ( !$role_id ) {
            $wiki->remove_user( user => $user );
            $c->session_object()
                ->add_message(
                loc( '%1 was removed as a wiki member.', $user->best_name() )
                );
        }
        else {
            my $role = Silki::Schema::Role->new( role_id => $role_id );
            my $current_role = $user->role_in_wiki($wiki);
            next if $role->role_id() == $current_role->role_id();

            $wiki->add_user( user => $user, role => $role );
            if ( $role->name eq 'Admin' ) {
                $c->session_object()->add_message(
                    loc(
                        '%1 is now an admin for this wiki.',
                        $user->best_name()
                    )
                );
            }
            else {
                $c->session_object()->add_message(
                    loc(
                        '%1 is no longer an admin for this wiki.',
                        $user->best_name()
                    )
                );
            }
        }
    }
}

sub _process_new_members {
    my $self = shift;
    my $c    = shift;

    my $wiki = $c->stash()->{wiki};

    my $params = $c->request()->params();

    for my $address ( Email::Address->parse( $params->{new_members} ) ) {
        my %message
            = string_is_empty( $params->{message} )
            ? ()
            : ( message => $params->{message} );

        my $user = Silki::Schema::User->new( email_address => $address->address() );
        if ($user) {
            if ( $user->is_wiki_member($wiki) ) {
                $c->session_object()->add_message(
                    loc(
                        '%1 is already a member of this wiki.',
                        $user->best_name()
                    )
                );
                next;
            }

            if ( $user->requires_activation() ) {
                $c->session_object()->add_message(
                    loc(
                        'An unactived account for %1 already exists. Once the account is activated, this user will be able to access this wiki.',
                        $user->best_name()
                    )
                );
            }
            else {
                $c->session_object()->add_message(
                    loc(
                        '%1 is now a member of this wiki.',
                        $user->best_name()
                    )
                );
            }

            $user->send_invitation_email(
                wiki   => $wiki,
                sender => $c->user(),
                %message,
            );
        }
        else {
            $user = Silki::Schema::User->insert(
                requires_activation => 1,
                disable_login       => 1,
                email_address       => $address->address(),
                (
                    $address->phrase()
                    ? ( display_name => $address->phrase() )
                    : ()
                ),
            );

            $user->send_activation_email(
                wiki   => $wiki,
                sender => $c->user(),
                %message,
            );

            $c->session_object()->add_message(
                loc(
                    'A user account for %1 has been created, and this person has been invited to join this wiki.',
                    $address->address()
                )
            );
        }

        $wiki->add_user(
            user => $user,
            role => Silki::Schema::Role->Member(),
        );
    }
}

sub new_page_form : Chained('_set_wiki') : PathPart('new_page_form') : Args(0)
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{title}    = $c->request()->params()->{title};
    $c->stash()->{template} = '/wiki/new_page_form';
}

sub page_collection : Chained('_set_wiki') : PathPart('page') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub page_collection_POST {
    my $self = shift;
    my $c    = shift;

    my $wiki = $c->stash()->{wiki};

    my $formatter = Silki::Formatter::HTMLToWiki->new(
        user => $c->user(),
        wiki => $wiki,
    );

    my $wikitext
        = $formatter->html_to_wikitext( $c->request()->params()->{content} );

    my $page = Silki::Schema::Page->insert_with_content(
        title   => $c->request()->params()->{title},
        content => $wikitext,
        wiki_id => $wiki->wiki_id(),
        user_id => $c->user()->user_id(),
    );

    $c->redirect_and_detach( $page->uri() );
}

sub _set_file : Chained('_set_wiki') : PathPart('file') : CaptureArgs(1) {
    my $self    = shift;
    my $c       = shift;
    my $file_id = shift;

    my $file = Silki::Schema::File->new( file_id => $file_id );

    my $wiki = $c->stash()->{wiki};
    $c->redirect_and_detach( $wiki->uri( with_host => 1 ) )
        unless $file && $file->wiki_id() == $wiki->wiki_id();

    $c->stash()->{file} = $file;
}

sub file : Chained('_set_file') : PathPart('') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub file_GET_html {
    my $self = shift;
    my $c    = shift;

    my $file = $c->stash()->{file};

    if ( $file->is_displayable_in_browser() ) {
        $c->stash()->{template} = '/file/view-in-frame';
    }
    else {
        $self->_file_download( $c, $file );
    }

    return;
}

sub file_download : Chained('_set_file') : PathPart('download') : Args(0) {
    my $self = shift;
    my $c    = shift;

    $self->_file_download( $c, $c->stash()->{file}, 'inline' );

    return;
}

sub _file_download {
    my $self        = shift;
    my $c           = shift;
    my $file        = shift;
    my $disposition = shift || 'attachment';

    $c->response()->content_type( $file->mime_type() );

    my $name = $file->file_name();
    $name =~ s/\"/\\"/g;

    $c->response()
        ->header( 'Content-Disposition' => qq{$disposition; filename="$name"} );
    $c->response()->content_length( $file->file_size() );
    $c->response()->header( 'X-Sendfile' => $file->file_on_disk() );
}

sub file_thumbnail : Chained('_set_file') : PathPart('thumbnail') : Args(0) {
    my $self = shift;
    my $c    = shift;

    my $file = $c->stash()->{file};

    $c->status_not_found()
        unless $file->is_browser_displayable_image();

    my $thumbnail = $file->thumbnail_file();

    $c->response()->status(200);
    $c->response()->content_type( $file->mime_type() );
    $c->response()->content_length( -s $thumbnail );
    $c->response()->header( 'X-Sendfile' => $thumbnail );

    return;
}

sub _set_user : Chained('_set_wiki') : PathPart('user') : CaptureArgs(1) {
}

sub _make_user_uri {
    my $self = shift;
    my $c    = shift;
    my $user = shift;
    my $view = shift || undef;

    my $real_view = 'user/' . $user->user_id();
    $real_view .= q{/} . $view if defined $view;

    return $c->stash()->{wiki}->uri( view => $real_view );
}

{
    use HTTP::Body::MultiPart;
    package HTTP::Body::MultiPart;

    no warnings 'redefine';
sub handler {
    my ( $self, $part ) = @_;

    unless ( exists $part->{name} ) {

        my $disposition = $part->{headers}->{'Content-Disposition'};
        my ($name)      = $disposition =~ / name="?([^\";]+)"?/;
        my ($filename)  = $disposition =~ / filename="?([^\"]*)"?/;
        # Need to match empty filenames above, so this part is flagged as an upload type

        $part->{name} = $name;

        if ( defined $filename ) {
            $part->{filename} = $filename;

            if ( $filename ne "" ) {
                my $fh = File::Temp->new( UNLINK => 0, DIR => $self->tmpdir, SUFFIX => q{-} . $filename );

                $part->{fh}       = $fh;
                $part->{tempname} = $fh->filename;
            }
        }
    }

    if ( $part->{fh} && ( my $length = length( $part->{data} ) ) ) {
        $part->{fh}->write( substr( $part->{data}, 0, $length, '' ), $length );
    }

    if ( $part->{done} ) {

        if ( exists $part->{filename} ) {
            if ( $part->{filename} ne "" ) {
                $part->{fh}->close if defined $part->{fh};

                delete @{$part}{qw[ data done fh ]};

                $self->upload( $part->{name}, $part );
            }
        }
        else {
            $self->param( $part->{name}, $part->{data} );
        }
    }
}
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
