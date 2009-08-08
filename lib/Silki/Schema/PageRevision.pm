package Silki::Schema::PageRevision;

use strict;
use warnings;

use Silki::Config;
use Silki::Formatter;
use Silki::Schema::Page;
use Silki::Schema;

use Fey::ORM::Table;

has_policy 'Silki::Schema::Policy';

has_table( Silki::Schema->Schema()->table('PageRevision') );

has_one( Silki::Schema->Schema()->table('Page') );

has_one( Silki::Schema->Schema()->table('User') );


sub body_as_html
{
    my $self = shift;

    return
        Silki::Formatter
            ->new( wiki => $self->page()->wiki() )
            ->wikitext_to_html( $self->content() );
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();


1;

__END__
