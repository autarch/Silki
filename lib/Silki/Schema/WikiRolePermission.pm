package Silki::Schema::WikiRolePermission;

use strict;
use warnings;

use Silki::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

has_policy 'Silki::Schema::Policy';

has_table( Silki::Schema->Schema()->table('WikiRolePermission') );

no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();


1;

__END__


