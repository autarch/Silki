package Silki::Schema::Process;

use strict;
use warnings;
use namespace::autoclean;

use Fey::Literal::Function;
use Silki::Schema;

use Fey::ORM::Table;

my $Schema = Silki::Schema->Schema();

{
    has_policy 'Silki::Schema::Policy';

    has_table( $Schema->table('Process') );
}

sub update_status {
    my $self        = shift;
    my $status      = shift;
    my $is_complete = shift;
    my $success     = shift;

    $self->update(
        last_modified_datetime => Fey::Literal::Function->new('NOW'),
        status                 => ( $self->status() . $status . "\n" ),
        is_complete            => ( $is_complete ? 1 : 0 ),
        ( $success ? ( was_successful => 1 ) : () ),
    );
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a separate process

