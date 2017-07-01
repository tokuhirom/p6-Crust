use v6;
use Test;
use Crust::Test;
use HTTP::Request;

$Crust::Test::Impl = "MockHTTP";

test-p6w
    client => -> $cb {
        my $req = HTTP::Request.new(GET => "http://localhost/hello");
        my $res = $cb($req);
        is $res.content, 'Hello World'.encode;
        is $res.field('Content-Type').Str, 'text/plain';
        is $res.code, 200;
    },
    app => -> $env {
        start { 200, [ 'Content-Type' => 'text/plain' ], [ 'Hello World' ] };
    };

done-testing;
