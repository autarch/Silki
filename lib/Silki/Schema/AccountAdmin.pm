package Silki::Schema::AccountAdmin;

use strict;
use warnings;

use Silki::Schema;

use Fey::ORM::Table;

has_policy 'Silki::Schema::Policy';

my $Schema = Silki::Schema->Schema();

has_table( $Schema->table('AccountAdmin') );

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__


