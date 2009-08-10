package Silki::Schema::User;

use strict;
use warnings;

use Authen::Passphrase::BlowfishCrypt;
use List::AllUtils qw( first );
use Silki::Schema;
use Silki::Schema::Domain;

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( pos_validated_list );

my $Schema = Silki::Schema->Schema();

{
    my $user_t = $Schema->table('User');

    has_policy 'Silki::Schema::Policy';

    has_table $user_t;

    has_one 'creator' =>
        ( table => $user_t );

    has_many 'pages' =>
        ( table => $Schema->table('Page') );

    has_many 'wikis' =>
        ( table => $Schema->table('Wiki') );
}

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

around 'insert' => sub
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

    return $class->$orig(%p);
};

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
                           openid_uri     => q{},
                           disable_login  => 1,
                           is_system_user => 1,
                         );
}

sub role_in_wiki
{
    my $self   = shift;
    my ($wiki) = pos_validated_list( \@_, { isa => 'Silki::Schema::Wiki' } );

    my $select = Silki::Schema->SQLFactoryClass()->new_select();

    $select->select( $Schema->table('Role')->column('name') )
           ->from( $Schema->table('Role'), $Schema->table('UserWikiRole') )
           ->where( $Schema->table('UserWikiRole')->column('wiki_id'),
                    '=', $wiki->wiki_id() )
           ->and( $Schema->table('UserWikiRole')->column('user_id'),
                    '=', $self->user_id() );

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($select)->dbh();

    my $row = $dbh->selectrow_arrayref( $select->sql($dbh), {}, $select->bind_params() );

    return
          $row              ? $row->[0]
        : $self->is_guest() ? 'Guest'
        :                     'Authenticated';
}

no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();


1;

__END__


