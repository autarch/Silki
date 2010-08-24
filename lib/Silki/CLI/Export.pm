package Silki::CLI::Export;

use strict;
use warnings;
use namespace::autoclean;
use autodie;

use Cwd qw( abs_path );
use Path::Class qw( dir );
use Silki::Schema::Wiki;
use Silki::Types qw( Str );
use Silki::Wiki::Exporter;

use Moose;

with 'MooseX::Getopt::Dashes';

has wiki => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has dir => (
    is      => 'ro',
    isa     => Str,
    default => abs_path(),
);

sub run {
    my $self = shift;

    my $wiki = Silki::Schema::Wiki->new( short_name => $self->wiki() );

    my $tarball = Silki::Wiki::Exporter->new( wiki => $wiki )->tarball();

    my $new_name = dir( $self->dir() )->file( $tarball->basename() );
    rename $tarball => $new_name;

    print "\n";
    print '  The '
        . $wiki->short_name()
        . ' wiki has been exported at '
        . $new_name;
    print "\n\n";

    exit 0;
}

# Intentionally not made immutable, since we only ever make one of these
# objects in a process.

1;
