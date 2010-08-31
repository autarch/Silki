package Silki::CLI::Export;

use strict;
use warnings;
use namespace::autoclean;
use autodie;

use Cwd qw( abs_path );
use Path::Class qw( dir );
use Silki::Schema::Process;
use Silki::Schema::Wiki;
use Silki::Types qw( Str );
use Silki::Wiki::Exporter;

use Moose;
use Moose::Util::TypeConstraints;

with 'MooseX::Getopt::Dashes';

{
    subtype 'Wiki', as 'Silki::Schema::Wiki';
    coerce 'Wiki',
        from Str,
        via { Silki::Schema::Wiki->new( short_name => $_ ) };

    MooseX::Getopt::OptionTypeMap->add_option_type_to_map( 'Wiki' => '=s' );

    has wiki => (
        is       => 'ro',
        isa      => 'Wiki',
        required => 1,
        coerce   => 1,
    );
}

has file => (
    is        => 'ro',
    isa       => Str,
    predicate => '_has_file',
);

{
    subtype 'Process', as 'Silki::Schema::Process';
    coerce 'Process',
        from Str,
        via { Silki::Schema::Process->new( process_id => $_ ) };

    MooseX::Getopt::OptionTypeMap->add_option_type_to_map(
        'Process' => '=s' );

    has process => (
        is     => 'ro',
        isa    => 'Process',
        coerce => 1,
    );
}

sub run {
    my $self = shift;

    $self->process()->update(
        status     => 'Starting work',
        system_pid => $$,
    ) if $self->process();

    my $file = eval { $self->_export() };

    if ( my $e = $@ ) {
        $self->_handle_error($e);
    }
    else {
        $self->_handle_success($file);
    }
}

sub _handle_error {
    my $self  = shift;
    my $error = shift;

    if ( $self->process() ) {
        $self->process()->update(
            status      => "Error doing work: $error",
            is_complete => 1,
        );
    }
    else {
        die $error;
    }

    exit 1;
}

sub _handle_success {
    my $self     = shift;
    my $new_name = shift;

    if ( $self->process() ) {
        $self->process()->update(
            status         => 'Completed work',
            is_complete    => 1,
            was_successful => 1,
        );
    }
    else {
        print "\n";
        print '  The '
            . $self->wiki()->short_name()
            . ' wiki has been exported at '
            . $new_name;
        print "\n\n";

    }

    exit 0;
}

sub _export {
    my $self = shift;

    my %p = ( wiki => $self->wiki() );

    if ( $self->process() ) {
        my $process = $self->process();

        $p{log} = sub { $process->update( status => join '', @_ ) };
    }

    my $tarball = Silki::Wiki::Exporter->new(%p)->tarball();

    my $new_name
        = $self->_has_file()
        ? $self->file()
        : dir( abs_path() )->file( $tarball->basename() );

    rename $tarball => $new_name;

    return $new_name;
}

# Intentionally not made immutable, since we only ever make one of these
# objects in a process.

1;
