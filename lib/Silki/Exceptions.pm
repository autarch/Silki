package Silki::Exceptions;

use strict;
use warnings;

my %E;
BEGIN
{
    %E = ( 'Silki::Exception' =>
           { alias       => 'error',
             description => 'Generic super-class for Silki exceptions'
           },

           'Silki::Exception::DataValidation' =>
           { isa         => 'Silki::Exception',
             alias       => 'data_validation_error',
             fields      => ['errors'],
             description => 'Invalid data given to a method/function'
           },
         );
}

{
    package Silki::Exception::DataValidation;

    sub messages { @{ $_[0]->errors || [] } }

    sub full_message
    {
        if ( my @m = $_[0]->messages )
        {
            return join "\n", 'Data validation errors: ', map { ref $_ ? $_->{message} : $_ } @m;
        }
        else
        {
            return $_[0]->SUPER::full_message();
        }
    }
}


use Exception::Class (%E);

Silki::Exception->Trace(1);

use Exporter qw( import );

our @EXPORT_OK = map { $_->{alias} || () } values %E;

1;
