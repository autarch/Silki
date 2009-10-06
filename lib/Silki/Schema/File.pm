package Silki::Schema::File;

use strict;
use warnings;

use Silki::Schema;

use Fey::ORM::Table;

with 'Silki::Role::Schema::URIMaker';

my $Schema = Silki::Schema->Schema();

has_policy 'Silki::Schema::Policy';

has_table( $Schema->table('File') );

has_one( $Schema->table('User') );

has_one( $Schema->table('Wiki') );

sub _base_uri_path {
    my $self = shift;

    return '/file/' . $self->file_id();
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
