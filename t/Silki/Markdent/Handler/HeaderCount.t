use strict;
use warnings;

use Test::Most;

use lib 't/lib';

use Markdent::Event::HorizontalRule;
use Markdent::Event::StartHeader;
use Silki::Markdent::Handler::HeaderCount;

{
    test_count(
        [
            'HorizontalRule',
            [ 'StartHeader', level => 1 ],
            [ 'StartHeader', level => 2 ],
            [ 'StartHeader', level => 3 ],
            [ 'StartHeader', level => 4 ],
            [ 'StartHeader', level => 5 ],
            [ 'StartHeader', level => 6 ],
        ],
        4,
        'ignores horizontal rules and headers where level > 4'
    );
}

{
    test_count(
        [
            'HorizontalRule',
            [ 'StartHeader', level => 5 ],
            [ 'StartHeader', level => 6 ],
        ],
        0,
        'count is zero when there are no relevant events'
    );
}

done_testing();

sub test_count {
    my $names  = shift;
    my $expect = shift;
    my $desc   = shift;

    my $count = Silki::Markdent::Handler::HeaderCount->new();

    for my $name ( @{$names} ) {
        my $class
            = 'Markdent::Event::' . ( ref $name ? shift @{$name} : $name );

        my $event = $class->new( ref $name ? @{$name} : () );

        $count->handle_event($event);
    }

    is( $count->count(), $expect, $desc );
}
