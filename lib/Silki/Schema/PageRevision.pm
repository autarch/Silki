package Silki::Schema::PageRevision;

use strict;
use warnings;

use Algorithm::Diff qw( sdiff );
use String::Diff qw( diff );
use Silki::Config;
use Silki::Formatter::WikiToHTML;
use Silki::Schema;
use Silki::Schema::Page;
use Silki::Schema::PageLink;
use Silki::Schema::PendingPageLink;

use Fey::ORM::Table;
use MooseX::Params::Validate qw( validated_list );

my $Schema = Silki::Schema->Schema();

has_policy 'Silki::Schema::Policy';

has_table( $Schema->table('PageRevision') );

has_one( $Schema->table('Page') );

has_one( $Schema->table('User') );

transform content => deflate {
    return unless defined $_[1];
    $_[1] =~ s/\r\n|\r/\n/g;
    return $_[1];
};

around insert => sub {
    my $orig  = shift;
    my $class = shift;

    my $revision = $class->$orig(@_);

    $revision->_update_page_links();
};

after update => sub {
    my $self = shift;

    $self->_update_page_links();
};

sub _update_page_links {
    my $self = shift;

    my $links = Silki::Formatter::WikiToHTML->new(
        user => Silki::Schema::User->SystemUser(),
        wiki => $self->page()->wiki(),
    )->links( $self->content() );

    my @existing
        = map {
        {
            from_page_id => $self->page_id(),
            to_page_id   => $links->{$_}{page}->page_id(),
        }
        }
        grep { $links->{$_}{page} }
        keys %{$links};

    my @pending
        = map {
        {
            from_page_id  => $self->page_id(),
            to_wiki_id    => $links->{$_}{wiki}->wiki_id(),,
            to_page_title => $_,
        }
        }
        grep { !$links->{$_}{page} }
        keys %{$links};

    my $delete_existing = Silki::Schema->SQLFactoryClass()->new_delete();
    $delete_existing->delete()->from( $Schema->table('PageLink') )->where(
        $Schema->table('PageLink')->column('from_page_id'),
        '=', $self->page_id()
    );

    my $delete_pending = Silki::Schema->SQLFactoryClass()->new_delete();
    $delete_pending->delete()->from( $Schema->table('PendingPageLink') )
        ->where(
        $Schema->table('PendingPageLink')->column('from_page_id'),
        '=', $self->page_id()
        );

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($delete_existing)
        ->dbh();

    my $updates = sub {
        $dbh->do( $delete_existing->sql($dbh), {},
            $delete_existing->bind_params() );
        $dbh->do( $delete_pending->sql($dbh), {},
            $delete_pending->bind_params() );

        Silki::Schema::PageLink->insert_many(@existing)
            if @existing;
        Silki::Schema::PendingPageLink->insert_many(@pending)
            if @pending;
    };

    Silki::Schema->RunInTransaction($updates);
}

sub Diff {
    my $class = shift;
    my ( $rev1, $rev2 ) = validated_list(
        \@_,
        rev1 => { isa => 'Silki::Schema::PageRevision' },
        rev2 => { isa => 'Silki::Schema::PageRevision' },
    );

    my @rev1 = map { s/^\s+|\s+$//; $_ } split /\n\n+/, $rev1->content();
    my @rev2 = map { s/^\s+|\s+$//; $_ } split /\n\n+/, $rev2->content();

    return [
        map {
            $_->[0] eq 'c'
                ? [
                'c',
                [
                    $class->_merged_sdiff(
                        [ split /\s+/, $_->[1] ],
                        [ split /\s+/, $_->[2] ],
                        q{ },
                    )
                ]
                ]
                : $_
            } sdiff(
            \@rev1,
            \@rev2,
            )
    ];
}

sub _merged_sdiff {
    my $class    = shift;
    my $seq1     = shift;
    my $seq2     = shift;
    my $split_on = shift;

    my @diff = sdiff( $seq1, $seq2 );

    for ( my $x = $#diff; $x > 0; $x-- ) {
        if ( $diff[$x][0] eq $diff[ $x - 1 ][0] ) {
            $diff[ $x - 1 ][1] .= $split_on . $diff[$x][1];
            $diff[ $x - 1 ][2] .= $split_on . $diff[$x][2];

            splice @diff, $x, 1;
        }
    }

    return @diff;
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
