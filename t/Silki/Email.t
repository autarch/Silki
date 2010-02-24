use strict;
use warnings;

use Test::More;

use lib 't/lib';
use Silki::Test::FakeSchema;

use Cwd qw( abs_path );
use File::Temp qw( tempdir );
use List::AllUtils qw( first );
use Silki::Config;

BEGIN {
    Silki::Config->new()->mason_config_for_email->{comp_root}
        = abs_path('t/share/mason/email');
    Silki::Config->new()->mason_config_for_email->{data_dir}
        = tempdir( CLEANUP => 1 );
}

use Silki::Email;

{

    package Silki::Schema::User;

    no warnings 'redefine';

    my $user = Silki::Schema::User->new(
        user_id        => 42,
        display_name   => 'System User',
        username       => 'system-user',
        email_address  => 'system-user@example.com',
        password       => '*disabled*',
        is_system_user => 1,
        _from_query    => 1,
    );

    sub SystemUser {$user}
}

$ENV{EMAIL_SENDER_TRANSPORT} = 'Test';

Silki::Email::send_email(
    from            => 'foo@example.com',
    to              => 'bar@example.com',
    subject         => 'Test email',
    template        => 'test',
    template_params => { uri => 'http://example.com' },
);

my @deliveries = Email::Sender::Simple->default_transport()->deliveries();

is( scalar @deliveries, 1, 'one email was sent' );

my $email = $deliveries[0]{email}->cast('Email::MIME');

is(
    $email->header('From'),
    'foo@example.com',
    'From header is correct'
);

is(
    $email->header('To'),
    'bar@example.com',
    'To header is correct'
);

is(
    $email->header('Subject'),
    'Test email',
    'Subject header is correct'
);

like(
    $email->header('Message-ID'),
    qr/^<.+>$/,
    'Message-ID looks valid'
);

like(
    $email->header('X-Sender'),
    qr/^Silki version \d+\.\d+$/,
    'X-Sender header is correct'
);

my @parts = $email->parts();

my $html = first { $_->content_type() =~ m{^text/html} } @parts;

ok( $html, 'found an HTML part' );
is(
    $html->content_type(),
    'text/html; charset=utf-8',
    'html content type is text/html and includes charset'
);

like(
    $html->body(),
    qr{<p>
       \s+
       \QThe user can pass a <a href="http://example.com">uri</a>.\E
       \s+
       </p>}x,
    'html body includes template parameters'
);

my $text = first { $_->content_type() =~ m{^text/plain} } @parts;

ok( $text, 'found plain text part' );
is(
    $text->content_type(),
    'text/plain; charset=utf-8',
    'text content type is text/plain and includes charset'
);

like(
    $text->body,
    qr{\QThe user can pass a uri (http://example.com).\E},
    'plain text body include uri from <a> tag'
);

done_testing();
