package Silki::Schema::User;

use strict;
use warnings;

use feature ':5.10';

use Authen::Passphrase::BlowfishCrypt;
use DateTime;
use Digest::SHA1 qw( sha1_hex );
use Fey::Literal::Function;
use Fey::Object::Iterator::FromSelect;
use Fey::ORM::Exceptions qw( no_such_row );
use Fey::Placeholder;
use List::AllUtils qw( all any first first_index );
use Silki::Email qw( send_email );
use Silki::I18N qw( loc );
use Silki::Schema;
use Silki::Schema::Domain;
use Silki::Schema::Permission;
use Silki::Schema::Role;
use Silki::Types qw( Int Str Bool );
use Silki::Util qw( string_is_empty );

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( pos_validated_list validated_list );

my $Schema = Silki::Schema->Schema();

with 'Silki::Role::Schema::URIMaker';

with 'Silki::Role::Schema::DataValidator' => {
    steps => [
        '_has_password_or_openid_uri',
        '_email_address_is_unique',
        '_normalize_and_validate_openid_uri',
        '_openid_uri_is_unique',
    ],
};

has_policy 'Silki::Schema::Policy';

has_table( $Schema->table('User') );

has_one 'creator' => ( table => $Schema->table('User') );

has_many 'pages' => ( table => $Schema->table('Page') );

has best_name => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_best_name',
    clearer => '_clear_best_name',
);

has has_login_credentials => (
    is      => 'ro',
    isa     => Bool,
    lazy    => 1,
    builder => '_build_has_login_credentials',
    clearer => '_clear_has_login_credentials',
);

class_has _RoleInWikiSelect => (
    is      => 'ro',
    does    => 'Fey::Role::SQL::ReturnsData',
    lazy    => 1,
    builder => '_BuildRoleInWikiSelect',
);

class_has _PrivateWikiCountSelect => (
    is      => 'ro',
    does    => 'Fey::Role::SQL::ReturnsData',
    lazy    => 1,
    builder => '_BuildPrivateWikiCountSelect',
);

class_has _PrivateWikiSelect => (
    is      => 'ro',
    does    => 'Fey::Role::SQL::ReturnsData',
    lazy    => 1,
    builder => '_BuildPrivateWikiSelect',
);

class_has _AllWikiCountSelect => (
    is      => 'ro',
    does    => 'Fey::Role::SQL::ReturnsData',
    lazy    => 1,
    builder => '_BuildAllWikiCountSelect',
);

class_has _AllWikiSelect => (
    is      => 'ro',
    does    => 'Fey::Role::SQL::ReturnsData',
    lazy    => 1,
    builder => '_BuildAllWikiSelect',
);

class_has _SharedWikiSelect => (
    is      => 'ro',
    isa     => 'Fey::SQL::Union',
    lazy    => 1,
    builder => '_BuildSharedWikiSelect',
);

class_has 'SystemUser' => (
    is      => 'ro',
    isa     => __PACKAGE__,
    lazy    => 1,
    default => sub { __PACKAGE__->_FindOrCreateSystemUser() },
);

class_has 'GuestUser' => (
    is      => 'ro',
    isa     => __PACKAGE__,
    lazy    => 1,
    default => sub { __PACKAGE__->_FindOrCreateGuestUser() },
);

{
    my $select = __PACKAGE__->_PrivateWikiCountSelect();

    has private_wiki_count => (
        metaclass   => 'FromSelect',
        is          => 'ro',
        isa         => Int,
        select      => $select,
        bind_params => sub { $_[0]->user_id(), $select->bind_params() },
    );
}

{
    my $select = __PACKAGE__->_PrivateWikiSelect();

    has_many private_wikis => (
        table       => $Schema->table('Wiki'),
        select      => $select,
        bind_params => sub { $_[0]->user_id(), $select->bind_params() },
    );
}

{
    my $select = __PACKAGE__->_AllWikiCountSelect();

    has all_wiki_count => (
        metaclass   => 'FromSelect',
        is          => 'ro',
        isa         => Int,
        select      => $select,
        bind_params => sub { ( $_[0]->user_id() ) x 3 },
    );
}

{
    my $select = __PACKAGE__->_AllWikiSelect();

    has_many all_wikis => (
        table       => $Schema->table('Wiki'),
        select      => $select,
        bind_params => sub { ( $_[0]->user_id() ) x 3 },
    );
}

my $DisabledPW = '*disabled*';
around insert => sub {
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    if ( delete $p{requires_activation} ) {
        $p{disable_login} = 1
            if string_is_empty( $p{password} );

        $p{activation_key}
            = sha1_hex( $p{email_address}, Silki::Config->new()->secret() );
    }

    if ( delete $p{disable_login} ) {
        $p{password} = $DisabledPW;
    }
    elsif ( $p{password} ) {
        $p{password} = $class->_password_as_rfc2307( $p{password} );
    }

    $p{username} //= $p{email_address};

    return $class->$orig(%p);
};

around update => sub {
    my $orig = shift;
    my $self = shift;
    my %p    = @_;

    if (  !string_is_empty( $p{email_address} )
        && string_is_empty( $p{username} )
        && $self->username() eq $self->email_address() ) {
        $p{username} = $p{email_address};
    }

    # An empty password field in a form should be treated as "leave the
    # password alone", not an empty to set the field to null.
    if ( string_is_empty( $p{password} ) ) {
        delete $p{password}
            unless $self->password() eq $DisabledPW;
    }
    else {
        $p{password} = $self->_password_as_rfc2307( $p{password} );
    }

    $p{last_modified_datetime} = Fey::Literal::Function->new('NOW');

    return $self->$orig(%p);
};

after update => sub {
    $_[0]->_clear_best_name();
    $_[0]->_clear_has_login_credentials();
};

sub _password_as_rfc2307 {
    my $self = shift;
    my $pw   = shift;

    # XXX - require a certain length or complexity? make it
    # configurable?
    my $pass = Authen::Passphrase::BlowfishCrypt->new(
        cost        => 8,
        salt_random => 1,
        passphrase  => $pw,
    );

    return $pass->as_rfc2307();
}

sub _has_password_or_openid_uri {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    my $error = { message => loc('You must provide a password or OpenID.') };

    if ($is_insert) {
        return if $p->{disable_login};

        return $error
            if all { string_is_empty( $p->{$_} ) } qw( password openid_uri );

        return;
    }
    else {
        return $error
            if all { exists $p->{$_} && string_is_empty( $p->{$_} ) }
            qw( password openid_uri );

        return if any { ! string_is_empty( $p->{$_} ) } qw( password openid_uri );

        if ( string_is_empty( $p->{password} ) ) {
            return if $self->has_openid_uri();
        }
        elsif ( string_is_empty( $p->{openid_uri} ) ) {
            return if $self->has_password();
        }

        return $error;
    }
}

sub _email_address_is_unique {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if string_is_empty( $p->{email_address} );

    return if !$is_insert && $self->email_address() eq $p->{email_address};

    return unless __PACKAGE__->new( email_address => $p->{email_address} );

    return {
        field   => 'email_address',
        message => loc(
            'The email address you provided is already in use by another account.'
        ),
    };
}

sub _normalize_and_validate_openid_uri {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if string_is_empty( $p->{openid_uri} );

    my $uri = URI->new( $p->{openid_uri} );

    unless ( defined $uri->scheme()
        && $uri->scheme() =~ /^https?/ ) {
        return {
            field   => 'openid_uri',
            message => loc('The OpenID you provided is not a valid URI.'),
        };
    }

    $p->{openid_uri} = $uri->canonical() . q{};

    return;
}

sub _openid_uri_is_unique {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if string_is_empty( $p->{openid_uri} );

    return if !$is_insert && $self->openid_uri() eq $p->{openid_uri};

    return unless __PACKAGE__->new( openid_uri => $p->{openid_uri} );

    return {
        field   => 'openid_uri',
        message => loc(
            'The OpenID URI you provided is already in use by another account.'
        ),
    };
}

sub _base_uri_path {
    my $self = shift;

    return '/user/' . $self->user_id();
}

sub domain {
    my $self = shift;

    my $wiki = $self->private_wikis()->next();
    $wiki ||= $self->all_wikis()->next();

    return $wiki ? $wiki->domain() : Silki::Schema::Domain->DefaultDomain();
}

sub EnsureRequiredUsersExist {
    my $class = shift;

    $class->_FindOrCreateSystemUser();

    $class->_FindOrCreateGuestUser();
}

{
    my $SystemUsername = 'system-user';

    sub _FindOrCreateSystemUser {
        my $class = shift;

        return $class->_FindOrCreateSpecialUser($SystemUsername);
    }
}

{
    my $GuestUsername = 'guest-user';

    sub _FindOrCreateGuestUser {
        my $class = shift;

        return $class->_FindOrCreateSpecialUser($GuestUsername);
    }

    sub is_guest {
        my $self = shift;

        return $self->username() eq $GuestUsername;
    }
}

sub _FindOrCreateSpecialUser {
    my $class    = shift;
    my $username = shift;

    my $user = eval { $class->new( username => $username ) };

    return $user if $user;

    return $class->_CreateSpecialUser($username);
}

sub _CreateSpecialUser {
    my $class    = shift;
    my $username = shift;

    my $domain = Silki::Schema::Domain->DefaultDomain();

    my $email = $username . q{@} . $domain->email_hostname();

    my $display_name = join ' ', map {ucfirst} split /-/, $username;

    return $class->insert(
        display_name   => $display_name,
        username       => $username,
        email_address  => $email,
        password       => q{},
        disable_login  => 1,
        is_system_user => 1,
    );
}

sub set_time_zone_for_dt {
    my $self = shift;
    my $dt   = shift;

    return $dt->clone()->set_time_zone( $self->time_zone() );
}

sub _build_best_name {
    my $self = shift;

    return $self->display_name() if length $self->display_name;

    my $username = $self->username();

    if ( $username =~ /\@/ ) {
        $username =~ s/\@.+$//;
    }

    return $username;
}

sub _build_has_login_credentials {
    my $self = shift;

    return 1 if !string_is_empty( $self->openid_uri() );

    return 1
        if !string_is_empty( $self->password() )
            && $self->password ne $DisabledPW;
}

sub requires_activation {
    my $self = shift;

    return defined $self->activation_key();
}

sub activation_uri {
    my $self = shift;
    my %p    = @_;

    die
        'Cannot make an activation uri for a user which does not need activation.'
        unless $self->requires_activation();

    my $view = $p{view} || 'preferences_form';

    $p{view} = 'activation/' . $self->activation_key() . q{/} . $view;

    return $self->uri(%p);
}

sub check_password {
    my $self = shift;
    my $pw   = shift;

    return if $self->is_system_user();

    return if $self->password() eq $DisabledPW;

    my $pass = Authen::Passphrase::BlowfishCrypt->from_rfc2307(
        $self->password() );

    return $pass->match($pw);
}

sub is_authenticated {
    my $self = shift;

    return !$self->is_system_user();
}

sub can_edit_user {
    my $self = shift;
    my $user = shift;

    return 0 if $user->is_system_user();

    return 1 if $self->is_admin();

    return 1 if $self->user_id() == $user->user_id();

    return 0;
}

sub has_permission_in_wiki {
    my $self = shift;
    my ( $wiki, $perm ) = validated_list(
        \@_,
        wiki       => { isa => 'Silki::Schema::Wiki' },
        permission => { isa => 'Silki::Schema::Permission' },
    );

    my $perms = $wiki->permissions();

    my $role = $self->role_in_wiki($wiki);

    return $perms->{ $role->name() }{ $perm->name() };
}

sub is_wiki_member {
    my $self = shift;
    my ($wiki) = pos_validated_list( \@_, { isa => 'Silki::Schema::Wiki' } );

    my $role_name = $self->_role_name_in_wiki($wiki);

    return defined $role_name;
}

sub role_in_wiki {
    my $self = shift;
    my ($wiki) = pos_validated_list( \@_, { isa => 'Silki::Schema::Wiki' } );

    my $role_name = $self->_role_name_in_wiki($wiki);

    $role_name ||=
        $self->is_guest()
        ? 'Guest'
        : 'Authenticated';

    return Silki::Schema::Role->$role_name();
}

sub _role_name_in_wiki {
    my $self = shift;
    my $wiki = shift;

    my $select = $self->_RoleInWikiSelect();

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    my $row = $dbh->selectrow_arrayref(
        $select->sql($dbh),
        {},
        $wiki->wiki_id(),
        $self->user_id(),
    );

    return unless $row;

    return $row->[0];
}

sub _BuildRoleInWikiSelect {
    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    $select->select( $Schema->table('Role')->column('name') )
        ->from( $Schema->table('Role'), $Schema->table('UserWikiRole') )
        ->where(
        $Schema->table('UserWikiRole')->column('wiki_id'),
        '=', Fey::Placeholder->new()
        )->and(
        $Schema->table('UserWikiRole')->column('user_id'),
        '=', Fey::Placeholder->new()
        );
}

sub _BuildPrivateWikiCountSelect {
    my $class = shift;

    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    my $distinct = Fey::Literal::Term->new( 'DISTINCT ',
        $Schema->table('Wiki')->column('wiki_id') );
    my $count = Fey::Literal::Function->new( 'COUNT', $distinct );

    $select->select($count);
    $class->_PrivateWikiSelectBase($select);

    return $select;
}

sub _BuildPrivateWikiSelect {
    my $class = shift;

    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    $select->select( $Schema->table('Wiki') );
    $class->_PrivateWikiSelectBase($select);
    $select->order_by( $Schema->table('Wiki')->column('title') );

    return $select;
}

sub _PrivateWikiSelectBase {
    my $class  = shift;
    my $select = shift;

    my $guest  = Silki::Schema::Role->Guest();
    my $authed = Silki::Schema::Role->Authenticated();
    my $read   = Silki::Schema::Permission->Read();

    my $public_select = Silki::Schema->SQLFactoryClass()->new_select();

    $public_select->select(
        $Schema->table('WikiRolePermission')->column('wiki_id') )
        ->from( $Schema->table('WikiRolePermission') )->where(
        $Schema->table('WikiRolePermission')->column('role_id'),
        'IN', $guest->role_id(), $authed->role_id()
        )->and(
        $Schema->table('WikiRolePermission')->column('permission_id'),
        '=', $read->permission_id()
        );

    $select->from( $Schema->table('Wiki'), $Schema->table('UserWikiRole') )
        ->where(
        $Schema->table('UserWikiRole')->column('user_id'),
        '=', Fey::Placeholder->new()
        )->and(
        $Schema->table('Wiki')->column('wiki_id'),
        'NOT IN', $public_select
        );

    return;
}

sub wikis_shared_with {
    my $self = shift;
    my $user = shift;

    my $select = $self->_SharedWikiSelect();

    return Fey::Object::Iterator::FromSelect->new(
        classes => ['Silki::Schema::Wiki'],
        select  => $select,
        dbh => Silki::Schema->DBIManager()->source_for_sql($select)->dbh(),
        bind_params => [ ( $self->user_id(), $user->user_id() ) x 2 ],
    );
}

sub _BuildSharedWikiSelect {
    my $class = shift;

    my $explicit_wiki_select = Silki::Schema->SQLFactoryClass()->new_select();

    $explicit_wiki_select->select( $Schema->table('Wiki') );
    $class->_ExplicitWikiSelectBase($explicit_wiki_select);

    my $implicit_wiki_select = Silki::Schema->SQLFactoryClass()->new_select();

    $implicit_wiki_select->select( $Schema->table('Wiki') );
    $class->_ImplicitWikiSelectBase($implicit_wiki_select);

    my $intersect1 = Silki::Schema->SQLFactoryClass()->new_intersect;
    $intersect1->intersect( $explicit_wiki_select, $explicit_wiki_select );

    my $intersect2 = Silki::Schema->SQLFactoryClass()->new_intersect;
    $intersect2->intersect( $implicit_wiki_select, $implicit_wiki_select );

    my $union = Silki::Schema->SQLFactoryClass()->new_union;

    # To use an ORDER BY with a UNION in Pg, you specify the column as a
    # number (ORDER BY 5).
    my $title_idx = first_index { $_->name() eq 'title' }
    $Schema->table('Wiki')->columns();
    $union->union( $intersect1, $intersect2 )
        ->order_by( Fey::Literal::Term->new($title_idx) );

    return $union;
}

sub _BuildAllWikiCountSelect {
    my $class = shift;

    my $explicit_wiki_select = Silki::Schema->SQLFactoryClass()->new_select();

    $explicit_wiki_select->select(
        $Schema->table('Wiki')->column('wiki_id') );
    $class->_ExplicitWikiSelectBase($explicit_wiki_select);

    my $implicit_wiki_select = Silki::Schema->SQLFactoryClass()->new_select();

    $implicit_wiki_select->select(
        $Schema->table('Wiki')->column('wiki_id') );
    $class->_ImplicitWikiSelectBase($implicit_wiki_select);

    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    my $distinct = Fey::Literal::Term->new( 'DISTINCT ',
        $Schema->table('Wiki')->column('wiki_id') );
    my $count = Fey::Literal::Function->new( 'COUNT', $distinct );

    $select->select($count)->from( $Schema->table('Wiki') )->where(
        $Schema->table('Wiki')->column('wiki_id'),
        'IN', $explicit_wiki_select
        )->where('or')->where(
        $Schema->table('Wiki')->column('wiki_id'),
        'IN', $implicit_wiki_select
        );

    return $select;
}

sub _BuildAllWikiSelect {
    my $class = shift;

    my $explicit_wiki_select = Silki::Schema->SQLFactoryClass()->new_select();

    my $is_explicit1 = Fey::Literal::Term->new('1');
    $is_explicit1->set_alias_name('is_explicit');
    $explicit_wiki_select->select( $Schema->table('Wiki'), $is_explicit1 );
    $class->_ExplicitWikiSelectBase($explicit_wiki_select);

    my $implicit_wiki_select = Silki::Schema->SQLFactoryClass()->new_select();

    my $is_explicit0 = Fey::Literal::Term->new('0');
    $is_explicit0->set_alias_name('is_explicit');
    $implicit_wiki_select->select( $Schema->table('Wiki'), $is_explicit0 );
    $class->_ImplicitWikiSelectBase($implicit_wiki_select);

    my $union = Silki::Schema->SQLFactoryClass()->new_union;

    # To use an ORDER BY with a UNION in Pg, you specify the column as a
    # number (ORDER BY 5).
    my $is_explicit_idx = ( scalar $Schema->table('Wiki')->columns() ) + 1;

    my $title_idx = first_index { $_->name() eq 'title' }
        $Schema->table('Wiki')->columns();

    $union->union( $explicit_wiki_select, $implicit_wiki_select )->order_by(
        Fey::Literal::Term->new($is_explicit_idx),
        'DESC',
        Fey::Literal::Term->new($title_idx),
        'ASC',
    );

    return $union;
}

sub _ExplicitWikiSelectBase {
    my $class  = shift;
    my $select = shift;

    $select->from( $Schema->tables( 'Wiki', 'UserWikiRole' ) )->where(
        $Schema->table('UserWikiRole')->column('user_id'),
        '=', Fey::Placeholder->new()
    );

    return;
}

sub _ImplicitWikiSelectBase {
    my $class  = shift;
    my $select = shift;

    my $explicit = Silki::Schema->SQLFactoryClass()->new_select();
    $explicit->select( $Schema->table('Wiki')->column('wiki_id') );
    $class->_ExplicitWikiSelectBase($explicit);

    $select->from( $Schema->tables( 'Wiki', 'Page' ) )
           ->from( $Schema->tables( 'Page', 'PageRevision' ) )
           ->where( $Schema->table('PageRevision')->column('user_id'),
                    '=', Fey::Placeholder->new()
                  )
           ->and( $Schema->table('Wiki')->column('wiki_id'), 'NOT IN',
                  $explicit );

    return;
}

sub send_invitation_email {
    my $self = shift;

    $self->_send_email( @_, template => 'invitation' );
}

sub send_activation_email {
    my $self = shift;

    $self->_send_email( @_, template => 'activation' );
}

sub _send_email {
    my $self = shift;
    my ( $wiki, $sender, $message, $template ) = validated_list(
        \@_,
        wiki     => { isa => 'Silki::Schema::Wiki', optional => 1 },
        sender   => { isa => 'Silki::Schema::User' },
        message  => { isa => Str,                   optional => 1 },
        template => { isa => Str },
    );

    my $subject
        = $wiki
        ? loc(
        'You have been invited to participate in the %1 wiki at %2',
        $wiki->title(),
        $wiki->domain()->web_hostname(),
        )
        : loc(
        'Activate your account on the %1 server',
        $self->domain()->web_hostname
        );

    my $from = Email::Address->new(
        $sender->best_name(),
        $sender->email_address()
    )->format();

    send_email(
        from            => $from,
        subject         => $subject,
        to              => $self->email_address(),
        template        => $template,
        template_params => {
            user    => $self,
            wiki    => $wiki,
            sender  => $sender,
            message => $message,
        },
    );

    return;
}

no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__


