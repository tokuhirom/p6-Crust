use v6;
use Test;
use Crust::App::URLMap;
use Crust::Test;
use HTTP::Request;

my $app = Crust::App::URLMap.new;
$app.map: '/foo', sub ($env) { 200, [], ['hello'] };
$app.map: '/bar', sub ($env) { 200, [], ['world'] };
$app.map: 'http://localhost:5000/hello', sub ($env) { 200, [], ['こんにちわ'] };
$app.map: 'http://127.0.0.1:5000/world', sub ($env) { 200, [], ['世界'] };
$app
  .map('/perl6', sub ($env) { 200, [], ['perl6'] })
  .map('/perl5', sub ($env) { 200, [], ['perl5'] })
  .map('/path',  sub ($env) { 200, [], [$env<PATH_INFO>] });

my $client = -> $cb {
    my ($req, $res);
    $req = HTTP::Request.new(GET => "/foo");
    $res = $cb($req);
    is $res.code, 200;
    is $res.content.decode, "hello";

    $req = HTTP::Request.new(GET => "/bar");
    $res = $cb($req);
    is $res.code, 200;
    is $res.content.decode, "world";

    # TODO
    #$req = HTTP::Request.new(GET => "http://localhost:5000/hello");
    #$res = $cb($req);
    #is $res.code, 200;
    #is $res.content.decode, "こんにちわ";

    # TODO
    #$req = HTTP::Request.new(GET => "http://127.0.0.1:5000/world");
    #$res = $cb($req);
    #is $res.code, 200;
    #is $res.content.decode, "世界";

    $req = HTTP::Request.new(GET => "/zoo");
    $res = $cb($req);
    is $res.code, 404;

    $req = HTTP::Request.new(GET => "/perl6");
    $res = $cb($req);
    is $res.code, 200;
    is $res.content.decode, "perl6";

    $req = HTTP::Request.new(GET => "/perl5");
    $res = $cb($req);
    is $res.code, 200;
    is $res.content.decode, "perl5";

    $req = HTTP::Request.new(GET => "/path");
    $res = $cb($req);
    is $res.content.decode, "";
    $req = HTTP::Request.new(GET => "/path/");
    $res = $cb($req);
    is $res.content.decode, "/";
    $req = HTTP::Request.new(GET => "/path/bar");
    $res = $cb($req);
    is $res.content.decode, "/bar";
    $req = HTTP::Request.new(GET => "/path/bar/");
    $res = $cb($req);
    is $res.content.decode, "/bar/";
    $req = HTTP::Request.new(GET => "/pathbar");
    $res = $cb($req);
    is $res.code, 404;
};

test-psgi $app, $client;

done-testing;
