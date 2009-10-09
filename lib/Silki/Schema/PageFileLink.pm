package Silki::Schema::PageFileLink;

use strict;
use warnings;

use Silki::Schema;

use Fey::ORM::Table;

has_policy 'Silki::Schema::Policy';

has_table( Silki::Schema->Schema()->table('PageFileLink') );

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__


