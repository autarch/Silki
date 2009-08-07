package Silki::Controller::Root;

use strict;
use warnings;

use Moose;

BEGIN { extends 'Silki::Controller::Base' }

__PACKAGE__->config( namespace => q{} );

sub default : Private
{
    my $self = shift;
    my $c    = shift;

    $self->redirect_and_detach( $self->domain()->uri( view => '/site', with_host => 1 ) );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__

=head1 NAME

Silki::Controller::Root - Root Controller for Silki

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 default

=head2 end

Attempt to render a view, if needed.

=head1 AUTHOR

Dave Rolsky,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
