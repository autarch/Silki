package Silki::Role::OptionalLog;

use strict;
use warnings;
use namespace::autoclean;

use Silki::Types qw( CodeRef );

use Moose::Role;

has _log => (
    is        => 'ro',
    isa       => CodeRef,
    init_arg  => 'log',
    predicate => '_has_log',
);

sub _maybe_log {
    my $self = shift;

    return unless $self->_has_log();

    $self->_log()->(@_);

    return;
}

1;
