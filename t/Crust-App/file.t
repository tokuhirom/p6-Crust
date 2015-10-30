use v6;
use Test;
use Crust::App::File;
use Crust::Test;
use Crust::Utils;
use HTTP::Request;
use File::Temp;

my $tempdir = tempdir;
"$tempdir/hello.css".IO.spurt: q:to/EOF/;
.body {}
EOF
"$tempdir/js".IO.mkdir;
"$tempdir/js/foo.js".IO.spurt: q:to/EOF/;
(function () {
  console.log("hello");
}());
EOF
"$tempdir/secret".IO.spurt("");
"$tempdir/secret".IO.chmod(0o000);

my $app = Crust::App::File.new(:root($tempdir));
my $client = -> $cb {
    my ($req, $res);
    $req = HTTP::Request.new(GET => "/hello.css");
    $res = $cb($req);
    is $res.code, 200;
    is $res.field('Content-Type').Str, 'text/css; charset=utf-8';
    is $res.field('Last-Modified'), format-datetime-rfc1123(DateTime.new("$tempdir/hello.css".IO.modified));

    $req = HTTP::Request.new(GET => "/js/foo.js");
    $res = $cb($req);
    is $res.code, 200;
    is $res.field('Content-Type').Str, 'application/javascript';

    $req = HTTP::Request.new(GET => "/not-found");
    $res = $cb($req);
    is $res.code, 404;
    is $res.content.decode, "not found";

    $req = HTTP::Request.new(GET => "/");
    $res = $cb($req);
    is $res.code, 404;
    is $res.content.decode, "not found";

    unless $*DISTRO.is-win {
        $req = HTTP::Request.new(GET => "/secret");
        $res = $cb($req);
        is $res.code, 403;

        $req = HTTP::Request.new(GET => "/../.ssh/id_rsa");
        $res = $cb($req);
        is $res.code, 403;
    }
};

test-psgi $app, $client;

done-testing;
