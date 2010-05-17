package Silki::Help::File;

use strict;
use warnings;
use namespace::autoclean;

use File::Slurp qw( read_file );
use HTML::Entities qw( encode_entities );
use Silki::Types qw( ArrayRef File HashRef Str );

use Moose;
use MooseX::SemiAffordanceAccessor;

has file => (
    is       => 'ro',
    isa      => File,
    required => 1,
);

has content => (
    is       => 'ro',
    isa      => Str,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_content',
);

sub _build_content {
    my $self = shift;

    return read_file( $self->file()->stringify() );
}

__PACKAGE__->meta()->make_immutable();

1;

