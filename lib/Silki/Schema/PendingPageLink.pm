package Silki::Schema::PendingPageLink;

use strict;
use warnings;

use Silki::Schema;

use Fey::ORM::Table;

has_policy 'Silki::Schema::Policy';

has_table( Silki::Schema->Schema()->table('PendingPageLink') );

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__


