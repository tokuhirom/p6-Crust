use v6;
use Test;
use Crust::Test;
use Crust::Middleware::XFramework;
use HTTP::Request;

my $framework = 'AwesomeWAF';

my $app = -> $env {
    200, [ 'Content-Type' => 'text/plain' ], [ 'Hello World' ];
};
$app = Crust::Middleware::XFramework.new($app, :framework($framework));

test-psgi
    client => -> $cb {
        my $req = HTTP::Request.new(GET => "http://localhost/hello");
        my $res = $cb($req);
        is $res.field('X-Framework').Str, $framework;
    },
    app => $app;

done-testing;
