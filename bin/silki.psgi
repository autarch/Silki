#!/usr/bin/env perl
use strict;
use warnings;

use Silki;
use Plack::Builder;

builder {
    enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' }
        'Plack::Middleware::ReverseProxy';
    Silki->psgi_app();
};
