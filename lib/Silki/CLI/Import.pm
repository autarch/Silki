package Silki::CLI::Import;

use strict;
use warnings;
use namespace::autoclean;
use autodie;

use Silki::Schema::Domain;
use Silki::Types qw( Str );
use Silki::Wiki::Importer;

use Moose;

with qw( MooseX::Getopt::Dashes Silki::Role::CLI::HasOptionalProcess );

has tarball => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has domain => (
    is  => 'ro',
    isa => Str,
);

sub _run {
    my $self = shift;

    my %p;

    if ( $self->process() ) {
        $self->_replace_dbi_manager();

        my $process = $self->process();

        $p{log} = sub { $process->update( status => join '', @_ ) };
    }

    my $wiki;

    eval {
        $p{domain}
            = Silki::Schema::Domain->new( web_hostname => $self->domain() )
            if $self->domain();

        $wiki = Silki::Wiki::Importer->new(
            tarball => $self->tarball(),
            %p,
        )->imported_wiki();
    };

    return $wiki;
}

sub _final_result_string {
    my $self = shift;
    my $wiki = shift;

    return $wiki->uri();
}

sub _print_success_message {
    my $self = shift;
    my $wiki = shift;

    print "\n";
    print '  The ' . $wiki->short_name() . ' wiki has been imported.';
    print "\n";
    print '  You can visit it at ' . $wiki->uri( with_host => 1 );
    print "\n\n";
}

# This is a hack to make sure that updatess to the process table are not done
# inside the import transaction. Otherwise the status cannot actually be seen
# until the transaction finishes.
sub _replace_dbi_manager {
    my $self = shift;

    my $new_source = Silki::Schema->DBIManager()->default_source()
        ->clone( name => 'for Process updates' );

    my $man = _DBIManager->new();
    $man->add_source( Silki::Schema->DBIManager()->default_source() );
    $man->add_source($new_source);

    Silki::Schema->SetDBIManager($man);

    return;
}

{
    package _DBIManager;

    use Moose;

    extends 'Fey::DBIManager';

    override source_for_sql => sub {
        my $self = shift;
        my $sql  = shift;

        return $sql->isa('Fey::SQL::Update')
            && $sql->sql('Fey::FakeDBI') =~ /UPDATE "Process"/
            ? $self->get_source('for Process updates')
            : $self->get_source('default');
    };
}

# Intentionally not made immutable, since we only ever make one of these
# objects in a process.

1;
