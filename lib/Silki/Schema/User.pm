package Silki::Schema::User;

use strict;
use warnings;

use Authen::Passphrase::BlowfishCrypt;
use DateTime;
use Fey::Literal::Function;
use Fey::Object::Iterator::FromSelect;
use Fey::ORM::Exceptions qw( no_such_row );
use Fey::Placeholder;
use List::AllUtils qw( first first_index );
use Silki::I18N qw( loc );
use Silki::Schema;
use Silki::Schema::Domain;
use Silki::Schema::Role;
use Silki::Types qw( Str );
use Silki::Util qw( string_is_empty );

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( pos_validated_list validated_list );

my $Schema = Silki::Schema->Schema();

with 'Silki::Role::Schema::URIMaker';

with 'Silki::Role::Schema::DataValidator'
    => { steps => [ '_email_address_is_unique',
                    '_normalize_and_validate_openid_uri',
                    '_openid_uri_is_unique',
                  ],
       };

has_policy 'Silki::Schema::Policy';

has_table( $Schema->table('User') );

has_one 'creator' =>
    ( table => $Schema->table('User'));

has_many 'pages' =>
    ( table => $Schema->table('Page') );

has_many 'wikis' =>
    ( table => $Schema->table('Wiki') );

has best_name =>
    ( is      => 'ro',
      isa     => Str,
      lazy    => 1,
      builder => '_build_best_name',
    );

class_has _RoleInWikiSelect =>
    ( is      => 'ro',
      isa     => 'Fey::SQL::Select',
      lazy    => 1,
      builder => '_BuildRoleInWikiSelect',
    );

class_has _SharedWikiSelect =>
    ( is      => 'ro',
      isa     => 'Fey::SQL::Union',
      lazy    => 1,
      builder => '_BuildSharedWikiSelect',
    );

class_has 'SystemUser' =>
    ( is      => 'ro',
      isa     => __PACKAGE__,
      lazy    => 1,
      default => sub { __PACKAGE__->_FindOrCreateSystemUser() },
    );

class_has 'GuestUser' =>
    ( is      => 'ro',
      isa     => __PACKAGE__,
      lazy    => 1,
      default => sub { __PACKAGE__->_FindOrCreateGuestUser() },
    );

around insert => sub
{
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    if ( delete $p{disable_login} )
    {
        $p{password} = '*disabled*';
    }
    elsif ( $p{password} )
    {
        # XXX - require a certain length or complexity? make it
        # configurable?
        my $pass =
            Authen::Passphrase::BlowfishCrypt->new
                ( cost        => 8,
                  salt_random => 1,
                  passphrase  => $p{password},
                );

        $p{password} = $pass->as_rfc2307();
    }

    $p{username} ||= $p{email_address};

    my $locale = DateTime::Locale->load( $p{locale_code} || 'en_US' );
    $p{date_format} ||= $locale->date_format_default();
    $p{datetime_format} ||= $locale->datetime_format_default();

    $p{date_format_without_year} ||= $locale->format_for('MMMd');

    my $time_format =
          $locale->prefers_24_hour_time()
        ? $locale->format_for('Hms')
        : $locale->format_for('hms');

    $p{datetime_format_without_year} ||=
          $locale->date_before_time()
        ? $locale->format_for('MMMd') . q { } . $time_format
        : $time_format . q{ } . $locale->format_for('MMMd');

    return $class->$orig(%p);
};

around update => sub
{
    my $orig = shift;
    my $self = shift;
    my %p    = @_;

    if ( ! string_is_empty( $p{email_address} )
         && string_is_empty( $p{username} )
         && $self->username() eq $self->email_address() )
    {
        $p{username} = $p{email_address};
    }

    $p{last_modified_datetime} = Fey::Literal::Function->new('NOW');

    return $self->$orig(%p);
};

sub _load_from_dbms
{
    my $self = shift;
    my $p    = shift;

    # This gets set to the unhashed value in the constructor
    $self->_clear_password();

    $self->SUPER::_load_from_dbms($p);

    return unless $p->{password};

    no_such_row 'User cannot login'
        if $self->password() eq '*disabled*';

    my $pass =
        Authen::Passphrase::BlowfishCrypt->from_rfc2307( $self->password() );

    no_such_row 'Invalid password'
        unless $pass->match( $p->{password} );
}

sub _email_address_is_unique
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if string_is_empty( $p->{email_address} );

    return if ! $is_insert && $self->email_address() eq $p->{email_address};

    return unless __PACKAGE__->new( email_address => $p->{email_address} );

    return { field   => 'email_address',
             message => loc('The email address you provided is already in use by another account.'),
           };
}

sub _normalize_and_validate_openid_uri
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if string_is_empty( $p->{openid_uri} );

    my $uri = URI->new( $p->{openid_uri} );

    unless ( defined $uri->scheme()
             && $uri->scheme() =~ /^https?/ )
    {
        return { field   => 'openid_uri',
                 message => loc('The OpenID URI you provided is not a valid URI.'),
               };
    }

    $p->{openid_uri} = $uri->canonical() . q{};

    return;
}

sub _openid_uri_is_unique
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if string_is_empty( $p->{openid_uri} );

    return if ! $is_insert && $self->openid_uri() eq $p->{openid_uri};

    return unless __PACKAGE__->new( openid_uri => $p->{openid_uri} );

    return { field   => 'openid_uri',
             message => loc('The OpenID URI you provided is already in use by another account.'),
           };
}

sub _base_uri_path
{
    my $self = shift;

    return '/user/' . $self->user_id();
}

sub EnsureRequiredUsersExist
{
    my $class = shift;

    $class->_FindOrCreateSystemUser();

    $class->_FindOrCreateGuestUser();
}

{
    my $SystemUsername = 'system-user';

    sub _FindOrCreateSystemUser
    {
        my $class = shift;

        return $class->_FindOrCreateSpecialUser($SystemUsername);
    }
}

{
    my $GuestUsername = 'guest-user';

    sub _FindOrCreateGuestUser
    {
        my $class = shift;

        return $class->_FindOrCreateSpecialUser($GuestUsername);
    }

    sub is_guest
    {
        my $self = shift;

        return $self->username() eq $GuestUsername;
    }
}

sub is_authenticated
{
    my $self = shift;

    return ! $self->is_system_user();
}

sub _FindOrCreateSpecialUser
{
    my $class    = shift;
    my $username = shift;

    my $user = eval { $class->new( username => $username ) };

    return $user if $user;

    return $class->_CreateSpecialUser($username);
}

sub _CreateSpecialUser
{
    my $class    = shift;
    my $username = shift;

    my $domain = Silki::Schema::Domain->DefaultDomain();

    my $email = $username . q{@} . $domain->email_hostname();

    my $display_name = join ' ', map { ucfirst } split /-/, $username;

    return $class->insert( display_name   => $display_name,
                           username       => $username,
                           email_address  => $email,
                           password       => q{},
                           disable_login  => 1,
                           is_system_user => 1,
                         );
}

sub format_date
{
    my $self = shift;
    my $dt   = shift;

    $self->_format_dt( $dt, 'date' );
}

sub format_datetime
{
    my $self = shift;
    my $dt   = shift;

    $self->_format_dt( $dt, 'datetime' );
}

sub _format_dt
{
    my $self = shift;
    my $dt   = shift;
    my $type = shift;

    my $format_dt =
        $dt->clone()
           ->set( locale => $self->locale_code() )
           ->set_time_zone( $self->time_zone() );

    my $today = DateTime->today( time_zone => $self->time_zone() );

    my ( $without_year, $with_year ) =
        ( $type . '_format_without_year',
          $type . '_format'
        );

    my $format =
          $format_dt->year() == $today->year()
        ? $self->$without_year()
        : $self->$with_year();

    return $format_dt->format_cldr($format);
}

sub _build_best_name
{
    my $self = shift;

    return $self->display_name() if length $self->display_name;

    my $username = $self->username();

    if ( $username =~ /\@/ )
    {
        $username =~ s/\.\w+$//;
    }

    return $username;
}

sub can_edit_user
{
    my $self = shift;
    my $user = shift;

    return 1 if $self->is_admin();

    return 1 if $self->user_id() == $user->user_id();

    return 0;
}

sub has_permission_in_wiki
{
    my $self = shift;
    my ( $wiki, $perm ) =
        validated_list( \@_,
                        wiki       => { isa => 'Silki::Schema::Wiki' },
                        permission => { isa => 'Silki::Schema::Permission' },
                      );

    my $perms = $wiki->permissions();

    my $role = $self->role_in_wiki($wiki);

    return $perms->{ $role->name() }{ $perm->name() };
}

sub role_in_wiki
{
    my $self   = shift;
    my ($wiki) = pos_validated_list( \@_, { isa => 'Silki::Schema::Wiki' } );

    my $select = $self->_RoleInWikiSelect();

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    my $row = $dbh->selectrow_arrayref( $select->sql($dbh),
                                        {},
                                        $wiki->wiki_id(),
                                        $self->user_id(),
                                      );

    my $name =
          $row              ? $row->[0]
        : $self->is_guest() ? 'Guest'
        :                     'Authenticated';

    return Silki::Schema::Role->$name();
}

sub _BuildRoleInWikiSelect
{
    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    $select->select( $Schema->table('Role')->column('name') )
           ->from( $Schema->table('Role'), $Schema->table('UserWikiRole') )
           ->where( $Schema->table('UserWikiRole')->column('wiki_id'),
                    '=', Fey::Placeholder->new() )
           ->and( $Schema->table('UserWikiRole')->column('user_id'),
                    '=', Fey::Placeholder->new() );
}

sub wikis_shared_with
{
    my $self = shift;
    my $user = shift;

    my $select = $self->_SharedWikiSelect();
    warn $select->sql( Silki::Schema->DBIManager()->source_for_sql($select)->dbh() );
    return
        Fey::Object::Iterator::FromSelect->new
            ( classes     => [ 'Silki::Schema::Wiki' ],
              select      => $select,
              dbh         => Silki::Schema->DBIManager()->source_for_sql($select)->dbh(),
              bind_params => [ ( $self->user_id(), $user->user_id() ) x 2 ],
            );
}

sub _BuildSharedWikiSelect
{
    my $explicit_wiki_select = Silki::Schema->SQLFactoryClass()->new_select();

    $explicit_wiki_select
        ->select( $Schema->table('Wiki') )
        ->from( $Schema->tables( 'Wiki', 'UserWikiRole' ) )
        ->where( $Schema->table('UserWikiRole')->column('user_id'),
                 '=', Fey::Placeholder->new() );

    my $implicit_wiki_select = Silki::Schema->SQLFactoryClass()->new_select();

    $implicit_wiki_select
        ->select( $Schema->table('Wiki') )
        ->from( $Schema->tables( 'Wiki', 'Page' ) )
        ->from( $Schema->tables( 'Page', 'PageRevision' ) )
        ->where( $Schema->table('PageRevision')->column('user_id'),
                 '=', Fey::Placeholder->new() );

    my $intersect1 = Silki::Schema->SQLFactoryClass()->new_intersect;
    $intersect1->intersect( $explicit_wiki_select, $explicit_wiki_select );

    my $intersect2 = Silki::Schema->SQLFactoryClass()->new_intersect;
    $intersect2->intersect( $implicit_wiki_select, $implicit_wiki_select );

    my $union = Silki::Schema->SQLFactoryClass()->new_union;

    # To use an ORDER BY with a UNION in Pg, you specify the column as a
    # number (ORDER BY 5).
    my $title_idx =
        first_index { $_->name() eq 'title' } $Schema->table('Wiki')->columns();
    $union->union( $intersect1, $intersect2 )
          ->order_by( Fey::Literal::Term->new($title_idx) );

    return $union;
}

no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();


1;

__END__


