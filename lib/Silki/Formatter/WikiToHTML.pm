package Silki::Formatter::WikiToHTML;

use strict;
use warnings;

use HTML::Entities qw( encode_entities );
use Silki::I18N qw( loc );
use Silki::Schema::File;
use Silki::Schema::Page;
use Silki::Schema::Permission;
use Silki::Schema::Wiki;
use Silki::Types qw( Bool );
use Text::MultiMarkdown;

use Moose;
use MooseX::StrictConstructor;

has for_editor => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has _user => (
    is       => 'ro',
    isa      => 'Silki::Schema::User',
    required => 1,
    init_arg => 'user',
);

has _wiki => (
    is       => 'ro',
    isa      => 'Silki::Schema::Wiki',
    required => 1,
    init_arg => 'wiki',
);

has _tmm => (
    is       => 'ro',
    isa      => 'Text::MultiMarkdown',
    lazy     => 1,
    default  => sub { Text::MultiMarkdown->new() },
    init_arg => undef,
);

sub wikitext_to_html {
    my $self = shift;
    my $text = shift;

    $text = $self->_handle_wiki_links($text);

    return $self->_tmm()->markdown($text);
}

# Stolen from Text::Markdown
my $nested_parens;
$nested_parens = qr{
	(?> 								# Atomic matching
	   [^()]+							# Anything other than parens or whitespace
	 |
	   \(
		 (??{ $nested_parens })		# Recursive set of nested brackets
	   \)
	)*
}x;

my $link_re = qr/\[\[([^\]]+?)\]\](?:\(($nested_parens)\))?/;

sub _handle_wiki_links {
    my $self = shift;
    my $text = shift;

    $text =~ s/$link_re/$self->_link( $1, $2 )/eg;

    return $text;
}

sub _link {
    my $self = shift;
    my $link = shift;
    my $text = shift;

    my $thing = $self->_resolve_link( $link, $text );

    return unless $thing;

    if ( $thing->{file} ) {
        return $self->_link_to_file( %{$thing} );
    }
    else {
        return $self->_link_to_page( %{$thing} );
    }
}

sub _resolve_link {
    my $self = shift;
    my $link = shift;
    my $text = shift;

    if ( $link =~ /^file:(.+)/ ) {
        my $wiki = $self->_wiki();
        my $file_id = $1;

        if ( $link =~ m{^([^/]+)/([^/]+)$} ) {
            $wiki = Silki::Schema::Wiki->new( short_name => $1 )
                or return;

            $file_id = $2;
        }

        my $file = Silki::Schema::File->new( file_id => $file_id );

        unless ( defined $text ) {
            $text = $self->link_text_for_file(
                $wiki,
                $file,
            );
        }

        return {
            file => $file,
            text => $text,
        };
    }
    else {
        my $wiki = $self->_wiki();
        my $page_title = $link;

        if ( $link =~ m{^([^/]+)/([^/]+)$} ) {
            $wiki = Silki::Schema::Wiki->new( short_name => $1 )
                or return;

            $page_title = $2;
        }

        my $page = $self->_page_for_title( $page_title, $wiki );

        unless ( defined $text ) {
            $text = $self->link_text_for_page(
                $wiki,
                ( $page ? $page->title() : $page_title ),
            );
        }

        return {
            page  => $page,
            title => $page_title,
            text  => $text,
            wiki  => $wiki,
        };
    }
}

sub link_text_for_page {
    my $self       = shift;
    my $wiki       = shift;
    my $page_title = shift;

    my $text = $page_title;

    $text .= ' (' . $wiki->title() . ')'
        unless $wiki->wiki_id() == $self->_wiki()->wiki_id();

    return $text;
}

sub link_text_for_file {
    my $self = shift;
    my $wiki = shift;
    my $file = shift;

    return loc('Nonexistent file: $1') unless $file;

    my $text = $file->filename();

    $text .= ' (' . $wiki->title() . ')'
        unless $wiki->wiki_id() == $self->_wiki()->wiki_id();

    return $text;
}

sub _page_for_title {
    my $self  = shift;
    my $title = shift;
    my $wiki  = shift;

    return Silki::Schema::Page->new(
        title   => $title,
        wiki_id => $wiki->wiki_id(),
    ) || undef;
}

sub _link_to_file {
    my $self = shift;
    my %p    = shift;

    my $file = $p{file};

    return loc('Inaccessible file')
        unless $self->_user()->has_permission_in_wiki(
        wiki       => $file->wiki(),
        permission => Silki::Schema::Permission->Read(),
        );

    my $file_uri = $file->uri();

    my $dl = loc("Download this file");
    my $link_text = encode_entities( $p{text} );

    return qq{<a href="$file_uri" title="$dl">$link_text</a>};
}

sub _link_to_page {
    my $self = shift;
    my %p    = @_;

    my $page = $p{page};

    if ( $self->for_editor() ) {
        $page ||= Silki::Schema::Page->new(
            page_id     => 0,
            wiki_id     => $p{wiki}->wiki_id(),
            title       => $p{title},
            uri_path    => Silki::Schema::Page->TitleToURIPath( $p{title} ),
            _from_query => 1,
        );
    }

    my $uri
        = $page
        ? $page->uri()
        : $p{wiki}->uri( view => 'new_page_form', query => { title => $p{title} } );

    my $link_text = encode_entities( $p{text} );

    my $class = $page ? 'existing-page' : 'new-page';

    return qq{<a href="$uri" class="$class">$link_text</a>};
}

sub links {
    my $self     = shift;
    my $wikitext = shift;

    my %links;

    while ( $wikitext =~ /$link_re/g ) {
        $links{$1} = $self->_resolve_link( $1, $2 );
    }

    return \%links;
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
