use v6;
use Test;
use Crust::App::Directory;
use Crust::Test;
use HTTP::Request;
use File::Temp;

my $tempdir = tempdir;
"$tempdir/hello.css".IO.spurt: q:to/EOF/;
.body {}
EOF
"$tempdir/js".IO.mkdir;

my $app = Crust::App::Directory.new(
    :root($tempdir),
    app => sub ($env) {
        200, [], ['hello'];
    }
);
my $client = -> $cb {
    my ($req, $res);
    $req = HTTP::Request.new(GET => "/hello.css");
    $res = $cb($req);
    is $res.code, 200;
    is $res.field('Content-Type').Str, 'text/css; charset=utf-8';

    $req = HTTP::Request.new(GET => "/js/foo.js");
    $res = $cb($req);
    is $res.code, 404;

    $req = HTTP::Request.new(GET => "/js");
    $res = $cb($req);
    is $res.code, 301;

    $req = HTTP::Request.new(GET => "/js/");
    $res = $cb($req);
    is $res.code, 200;
    ok $res.content.decode ~~ /\<html\>/;

    $req = HTTP::Request.new(GET => "/");
    $res = $cb($req);
    is $res.code, 200;
    ok $res.content.decode ~~ /\<html\>/;

    $req = HTTP::Request.new(GET => "/../");
    $res = $cb($req);
    is $res.code, 403;
};

test-psgi $app, $client;

done-testing;
