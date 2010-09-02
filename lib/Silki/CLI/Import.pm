package Silki::CLI::Import;

use strict;
use warnings;
use namespace::autoclean;
use autodie;

use Silki::Schema::Domain;
use Silki::Types qw( Str );
use Silki::Wiki::Importer;

use Moose;

with qw( MooseX::Getopt::Dashes Silki::Role::CLI::HasOptionalProcess );

has tarball => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has domain => (
    is  => 'ro',
    isa => Str,
);

sub _run {
    my $self = shift;

    my %p;

    if ( $self->process() ) {
        my $process = $self->process();

        $p{log} = sub { $process->update( status => join '', @_ ) };
    }

    $p{domain} = Silki::Schema::Domain->new( web_hostname => $self->domain() )
        if $self->domain();

    return Silki::Wiki::Importer->new(
        tarball => $self->tarball(),
        %p,
    )->imported_wiki();
}

sub _print_success_message {
    my $self = shift;
    my $wiki = shift;

    print "\n";
    print '  The ' . $wiki->short_name() . ' wiki has been imported.';
    print "\n";
    print '  You can visit it at ' . $wiki->uri( with_host => 1 );
    print "\n\n";
}

# Intentionally not made immutable, since we only ever make one of these
# objects in a process.

1;
