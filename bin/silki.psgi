#!/usr/bin/env perl
use strict;
use warnings;
use Silki;

Silki->setup_engine('PSGI');
my $app = sub { Silki->run(@_) };

