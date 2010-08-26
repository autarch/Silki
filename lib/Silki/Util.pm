package Silki::Util;

use strict;
use warnings;

use Exporter qw( import );

use File::Which qw( which );
use Path::Class qw( file );

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
    my $executable = _find_executable( $_[0] );

    return if fork;

    require POSIX;
    exit 1 unless POSIX::setsid();

    if ( Silki::Schema->can('DBIManager') ) {
        $_->dbh()->{InactiveDestroy} = 1
            for Silki::Schema->DBIManager()->sources();
    }

    local $ENV{PERL5LIB} = join ':', @INC;
    exec {$executable} @_;

    die "Could not exec - $executable @_: $!";
}

sub _find_executable {
    my $executable = shift;

    my $path = which($executable);

    return $path if $path;

    my $rel = file( 'bin', $executable );

    return $rel if -x $rel;

    die "Cannot find an executable named $executable";
}

1;

# ABSTRACT: A utility module
