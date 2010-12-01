package Silki::Schema::Role;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

has_policy 'Silki::Schema::Policy';

has_table( Silki::Schema->Schema()->table('Role') );

# For i18n purposes:
# loc( 'Guest' )
# loc( 'Authenticated' )
# loc( 'Member' )
# loc( 'Admin' )

for my $role (qw( Guest Authenticated Member Admin )) {
    class_has $role => (
        is      => 'ro',
        isa     => 'Silki::Schema::Role',
        lazy    => 1,
        default => sub { __PACKAGE__->_FindOrCreateRole($role) },
    );
}

sub _FindOrCreateRole {
    my $class = shift;
    my $name  = shift;

    my $role = eval { $class->new( name => $name ) };

    $role ||= $class->insert( name => $name );

    return $role;
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a role
