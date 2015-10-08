use v6;
use Test;
use HTTP::Message::PSGI;
use HTTP::Request;

my $content = q|{"foo":"bar"}|;
my $req = HTTP::Request.new(
    POST => "http://localhost/post",
    Content-Type => "application/json",
);
$req.content = $content.encode;

my $env = $req.to-psgi;

is $env<CONTENT_LENGTH>, 13;
my $buf = $env<p6sgi.input>.read(13);
is $buf, $content.encode;

done-testing;
