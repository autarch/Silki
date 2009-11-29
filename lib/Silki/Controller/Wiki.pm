package Silki::Controller::Wiki;

use strict;
use warnings;

use Data::Page;
use Data::Page::FlickrLike;
use Email::Address;
use File::Basename qw( dirname );
use Path::Class ();
use Silki::Config;
use Silki::Formatter::HTMLToWiki;
use Silki::I18N qw( loc );
use Silki::Schema::Page;
use Silki::Schema::Wiki;
use Silki::Util qw( string_is_empty );

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

with 'Silki::Role::Controller::User', 'Silki::Role::Controller::UploadHandler';

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
        }, {
            uri     => $wiki->uri( view => 'recent' ),
            label   => loc('Recent Changes'),
            tooltip => loc('Recent activity in this wiki'),
            id      => 'recent-changes',
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

    $c->tab_by_id('recent-changes')->set_is_selected(1);

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

sub search : Chained('_set_wiki') : PathPart('search') : Args(0) : ActionClass('+Silki::Action::REST') {
}

sub search_GET_html {
    my $self = shift;
    my $c    = shift;

    my $wiki = $c->stash()->{wiki};

    my $search = $c->request()->params()->{search};

    $c->redirect_and_detach( $wiki->uri() )
        if string_is_empty($search);

    $c->stash()->{pages} = $wiki->text_search( query => $search );
    $c->stash()->{search} = $search;

    $c->stash()->{template} = '/wiki/search_results';
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
