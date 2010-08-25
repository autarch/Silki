package Silki::Util;

use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( string_is_empty english_list detach_and_run );

sub string_is_empty {
    return 1 if !defined $_[0] || !length $_[0];
    return 0;
}

sub english_list {
    return $_[0] if @_ <= 1;

    return join ' and ', @_ if @_ == 2;

    my $last = pop @_;

    return ( join ', ', @_ ) . ', and ' . $last;
}

sub detach_and_run {
    my $work    = shift;
    my $process = shift;

    return if fork;

    require POSIX;
    unless ( POSIX::setsid() ) {
        $process->update_status( "Cannot start a new session: $!" );
        exit 1;
    }

    $process->update_status( 'Starting work' );

    eval { $work->() };

    if (my $e = $@) {
        $process->update_status( "Error doing work: $e", 'complete' );
        exit 1;
    }
    else {
        $process->update_status( 'Completed work', 'complete', 1 );
        exit 0;
    }
}

1;

# ABSTRACT: A utility module
