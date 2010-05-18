package Silki::Help::File;

use strict;
use warnings;
use namespace::autoclean;

use File::Slurp qw( read_file );
use HTML::Entities qw( encode_entities );
use HTML::Mason::Interp;
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

my $Body;
my $Interp = HTML::Mason::Interp->new(
    out_method => \$Body,
    %{ Silki::Config->new()->mason_config_for_email() },
);

sub _build_content {
    my $self = shift;

    $Body = q{};
    $Interp->exec( $self->file()->stringify() );

    return $Body;
}

__PACKAGE__->meta()->make_immutable();

1;

