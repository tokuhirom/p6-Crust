use v6;

use Test;

use Crust::Headers;

my $headers = Crust::Headers.new({
    'Content-Type'   => 'text/html',
    'Content-Length' => '5000',
    'Referer' => 'http://mixi.jp',
    'User-Agent' => 'IE',
    'content-encoding' => 'gzip',
});
is $headers.header('ContEnt-TypE'), 'text/html';
is $headers.content-type, 'text/html';
is $headers.content-length, 5000;
is $headers.user-agent, 'IE';
is $headers.referer, 'http://mixi.jp';
is $headers.content-encoding, 'gzip';
ok $headers.Str ~~ /"content-length: 5000"/;

done-testing;

