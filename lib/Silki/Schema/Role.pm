package Silki::Schema::Role;

use strict;
use warnings;

use Silki::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

has_policy 'Silki::Schema::Policy';

has_table( Silki::Schema->Schema()->table('Role') );

for my $role ( qw( Guest Authenticated Member Admin ) )
{
    class_has $role =>
        ( is      => 'ro',
          isa     => 'Silki::Schema::Role',
          lazy    => 1,
          default => sub { __PACKAGE__->_CreateOrFindRole($role) },
        );
}

sub _CreateOrFindRole
{
    my $class = shift;
    my $name  = shift;

    my $role = eval { $class->new( name => $name ) };

    $role ||= $class->insert( name => $name );

    return $role;
}


no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();


1;

__END__


