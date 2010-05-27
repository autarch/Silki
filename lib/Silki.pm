package Silki;

use strict;
use warnings;
use namespace::autoclean;

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

# ABSTRACT: Silki is a Catalyst-based wiki hosting application

__END__

=pod

=head1 SYNOPSIS

    script/silki_server.pl

=head1 DESCRIPTION

Silki is a wiki hosting application with several core goals.

First, Silki aims to be easy to use. Many wiki applications seem to be aimed
at hackers, which is great, but wikis are useful in many fields, not just
geekery. Silki aims to be easy to use. That means building a simple UI,
providing hand-holding wherever it's needed, and avoiding jargon. It also
means that features take a back seat to usability. A bloated application is a
hard-to-use application.

Second, Silki is a I<wiki hosting platform>. That means that it can host
multiple wikis in a single installation. User identity is global to a single
installation, and users are members of zero or more wikis. Silki supports
various degrees of openness in a wiki, from "guests can edit" to "members
only".

Third, 

=cut
