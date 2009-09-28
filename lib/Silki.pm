package Silki;

use strict;
use warnings;

our $VERSION = '0.01';

use Catalyst::Runtime 5.8;

use CatalystX::RoleApplicator;
use Catalyst::Request::REST::ForBrowsers;
use Silki::Config;
use Silki::I18N ();
use Silki::Request;
use Silki::Schema;
use Silki::Web::Session;

use Moose;

my $Config;

BEGIN {
    extends 'Catalyst';

    $Config = Silki::Config->new();

    Catalyst->import( @{ $Config->catalyst_imports() } );

    Silki::Schema->LoadAllClasses();
}

with @{ $Config->catalyst_roles() };

__PACKAGE__->config(
    name => 'Silki',
    %{ $Config->catalyst_config() },
);

__PACKAGE__->request_class('Catalyst::Request::REST::ForBrowsers');
__PACKAGE__->apply_request_class_roles('Silki::Request');

Silki::Schema->EnableObjectCaches();

__PACKAGE__->setup();

sub loc {
    shift;
    Silki::I18N::loc(@_);
}

no Moose;

__PACKAGE__->meta()->make_immutable( replace_constructor => 1 );

1;

=head1 NAME

Silki - Catalyst based application

=head1 SYNOPSIS

    script/silk_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<Silki::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Dave Rolsky,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
