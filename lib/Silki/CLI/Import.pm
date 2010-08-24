package Silki::CLI::Import;

use strict;
use warnings;
use namespace::autoclean;
use autodie;

use Silki::Schema::Domain;
use Silki::Types qw( Str );
use Silki::Wiki::Importer;

use Moose;

with 'MooseX::Getopt::Dashes';

has tarball => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has domain => (
    is  => 'ro',
    isa => Str,
);

sub run {
    my $self = shift;

    my %domain
        = ( domain =>
            Silki::Schema::Domain->new( web_hostname => $self->domain() ) )
        if $self->domain();

    my $wiki = Silki::Wiki::Importer->new(
        tarball => $self->tarball(),
        %domain,
    )->imported_wiki();

    print "\n";
    print '  The ' . $wiki->short_name() . ' wiki has been imported.';
    print "\n";
    print '  You can visit it at ' . $wiki->uri( with_host => 1 );
    print "\n\n";

    exit 0;
}

# Intentionally not made immutable, since we only ever make one of these
# objects in a process.

1;
