package Silki::Role::CLI::HasOptionalProcess;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Schema::Process;
use Silki::Types qw( Str );

use Moose::Role;
use Moose::Util::TypeConstraints;

requires qw( _run _final_result_string _print_success_message );

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

    my @results = eval { $self->_run() };

    if ( my $e = $@ ) {
        $self->_handle_error($e);
    }
    else {
        $self->_handle_success(@results);
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
    my $self = shift;

    if ( $self->process() ) {
        $self->process()->update(
            status         => 'Completed work',
            is_complete    => 1,
            was_successful => 1,
            final_result   => $self->_final_result_string(@_),
        );
    }
    else {
        $self->_print_success_message(@_);
    }

    exit 0;
}

1;
