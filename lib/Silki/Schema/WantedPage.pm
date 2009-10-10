package Silki::Schema::WantedPage;

use strict;
use warnings;

use Silki::Schema::Page;
use Silki::Schema::Wiki;
use Silki::Types qw( Str Int );

use Moose;

with 'Silki::Role::Schema::URIMaker';

has title => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has wiki_id => (
    is       => 'ro',
    isa      => Int,
    required => 1,
);

has wiki => (
    is   => 'ro',
    isa  => 'Silki::Schema::Wiki',
    lazy => 1,
    default =>
        sub { Silki::Schema::Wiki->new( wiki_id => $_[0]->wiki_id() ) },
);

has wanted_count => (
    is       => 'ro',
    isa      => Int,
    required => 1,
);

sub _base_uri_path {
    my $self = shift;

    return $self->wiki()->_base_uri_path() . '/new_page_form';
}

around uri => sub {
    my $orig = shift;
    my $self = shift;
    my %p    = @_;

    $p{query} ||= {};

    $p{query}{title} = $self->title();

    return $self->$orig(%p);
};

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
