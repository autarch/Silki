package Silki::Schema::PageRevision;

use strict;
use warnings;

use Silki::Config;
use Silki::Formatter;
use Silki::Schema;
use Silki::Schema::Page;
use Silki::Schema::PageLink;
use Silki::Schema::PendingPageLink;

use Fey::ORM::Table;

my $Schema = Silki::Schema->Schema();

has_policy 'Silki::Schema::Policy';

has_table( $Schema->table('PageRevision') );

has_one( $Schema->table('Page') );

has_one( $Schema->table('User') );

transform content =>
    deflate { return unless defined $_[1];
              $_[1] =~ s/\r\n|\r/\n/g;
              return $_[1] };

around insert => sub
{
    my $orig  = shift;
    my $class = shift;

    my $revision = $class->$orig(@_);

    $revision->_update_page_links();
};

after update => sub
{
    my $self = shift;

    $self->_update_page_links();
};

sub _update_page_links
{
    my $self = shift;

    my $links = Silki::Formatter->new( user => Silki::Schema::User->SystemUser(),
                                       wiki => $self->page()->wiki(),
                                     )->links( $self->content() );


    my @existing =
        map { { from_page_id => $self->page_id(),
                to_page_id   => $links->{$_}{page}->page_id(),
              } }
        grep { $links->{$_}{page} }
        keys %{ $links };

    my @pending =
        map { { from_page_id  => $self->page_id(),
                to_wiki_id    => $links->{$_}{wiki}->wiki_id(),,
                to_page_title => $_,
              } }
        grep { ! $links->{$_}{page} }
        keys %{ $links };

    my $delete_existing = Silki::Schema->SQLFactoryClass()->new_delete();
    $delete_existing->delete()
                    ->from( $Schema->table('PageLink') )
                    ->where( $Schema->table('PageLink')->column('from_page_id'),
                             '=', $self->page_id() );

    my $delete_pending = Silki::Schema->SQLFactoryClass()->new_delete();
    $delete_pending->delete()
                    ->from( $Schema->table('PendingPageLink') )
                    ->where( $Schema->table('PendingPageLink')->column('from_page_id'),
                             '=', $self->page_id() );

    my $dbh = Silki::Schema->DBIManager()->source_for_sql($delete_existing)->dbh();

    my $updates = sub
    {
        $dbh->do( $delete_existing->sql($dbh), {}, $delete_existing->bind_params() );
        $dbh->do( $delete_pending->sql($dbh), {}, $delete_pending->bind_params() );

        Silki::Schema::PageLink->insert_many(@existing)
            if @existing;
        Silki::Schema::PendingPageLink->insert_many(@pending)
            if @pending;
    };

    Silki::Schema->RunInTransaction($updates);
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();


1;

__END__
