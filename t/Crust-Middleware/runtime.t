use v6;
use Test;
use Crust::Test;
use Crust::Middleware::Runtime;
use HTTP::Request;

my $app = -> $env {
    sleep 0.5;
    200, [ 'Content-Type' => 'text/plain' ], [ 'Hello World' ];
};
$app = ::('Crust::Middleware::Runtime').new($app);

test-psgi
    client => -> $cb {
        my $req = HTTP::Request.new(GET => "http://localhost/hello");
        my $res = $cb($req);
        ok $res.field('X-Runtime').Str >= 0.25, 'X-Runtime >= 0.25';
    },
    app => $app;

# with a differnt header-name
$app = -> $env {
    sleep 0.5;
    200, [ 'Content-Type' => 'text/plain' ], [ 'Hello World' ];
};
$app = ::('Crust::Middleware::Runtime').new($app, :header-name<X-RUNTIME-TEST>);

test-psgi
    client => -> $cb {
        my $req = HTTP::Request.new(GET => "http://localhost/hello");
        my $res = $cb($req);
        ok $res.field('X-RUNTIME-TEST').Str >= 0.25, 'X-RUNTIME-TEST >= 0.25';
    },
    app => $app;

done-testing;

