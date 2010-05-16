package Silki;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '0.01';

use Catalyst::Runtime 5.8;

use CatalystX::RoleApplicator;
use Catalyst::Plugin::Session 0.27;
use Catalyst::Request::REST::ForBrowsers;
use Silki::Config;
use Silki::I18N ();
use Silki::Request;
use Silki::Schema;
use Silki::Types qw( Str );
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

{
    package Catalyst::Plugin::Session;
    no warnings 'redefine';

    # XXX - monkey patch so that we don't try to read the value of sessionid
    # before prepare_action can set the session id from the URI.
    sub dump_these {
        return $_[0]->maybe::next::method;
    }
}

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
