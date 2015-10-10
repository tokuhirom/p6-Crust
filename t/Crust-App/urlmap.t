use v6;
use Test;
use Crust::App::URLMap;
use Crust::Test;
use HTTP::Request;

my $app = Crust::App::URLMap.new;
$app.map: '/foo', sub ($env) { [200, [], ['hello'.encode('ascii')]] };
$app.map: '/bar', sub ($env) { [200, [], ['world'.encode('ascii')]] };
$app.map: 'http://localhost:5000/hello', sub ($env) { [200, [], ['こんにちわ'.encode('utf-8')]] };
$app.map: 'http://127.0.0.1:5000/world', sub ($env) { [200, [], ['世界'.encode('utf-8')]] };

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
    #is $res.content.decode, "こんにちわ";
};

test-psgi $app, $client;

done-testing;
