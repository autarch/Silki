package Silki::Role::Controller::Pager;

use strict;
use warnings;
use namespace::autoclean;

use Moose::Role;

use Data::Page;
use Data::Page::FlickrLike;

sub _make_pager {
    my $self  = shift;
    my $c     = shift;
    my $total = shift;

    my $limit    = 50;
    my $page_num = $c->request()->params()->{page} || 1;
    my $offset   = $limit * ( $page_num - 1 );

    my $pager = Data::Page->new();
    $pager->total_entries($total);
    $pager->entries_per_page($limit);
    $pager->current_page($page_num);

    $c->stash()->{pager} = $pager;

    return ( $limit, $offset );
}

1;

# ABSTRACT: Provides a pager to controllers
