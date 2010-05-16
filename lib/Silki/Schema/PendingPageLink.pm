package Silki::Schema::PendingPageLink;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Schema;

use Fey::ORM::Table;

has_policy 'Silki::Schema::Policy';

has_table( Silki::Schema->Schema()->table('PendingPageLink') );

__PACKAGE__->meta()->make_immutable();

1;

__END__


