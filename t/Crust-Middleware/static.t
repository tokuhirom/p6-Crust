use v6;
use Test;
use Crust::Test;
use Crust::Builder;
use Crust::Middleware::Static;
use HTTP::Request;

$Crust::Test::Impl = "MockHTTP";

# TODO: Need to port more tests

my $app = builder {
    enable "Static",
        path => sub {
            # Perl6 strings are immutable, so you can't just modify
            # the path and expect the changes to be visible from the caller
            my $match = @_[0].subst-mutate(rx<^ '/share/'>, "");
            return ($match, @_[0]);
        },
        root => "share";
    enable "Static",
        path => rx:i{ '.foo' $},
        root => ".",
        content-type => sub ($file) { "text/x-fooo" };
    -> %env {
        return (200, [ 'Content-Type' => 'text/plain' ], [ 'Hello World' ]);
    };
};

test-psgi
    client => -> $cb {
        my ($req, $res);

        $req = HTTP::Request.new(GET => "http://localhost/hello");
        $res = $cb($req);
        is $res.code, 200;
        is $res.content.decode, "Hello World";

        $req = HTTP::Request.new(GET => "http://localhost/share/face.jpg");
        $res = $cb($req);
        is $res.code, 200;
        like $res.field('Content-Type').Str, rx:i{image};

        $req = HTTP::Request.new(GET => "http://localhost/share/doesnotexist");
        $res = $cb($req);
        is $res.code, 404;

        $req = HTTP::Request.new(GET => "http://localhost/t/Crust-Middleware/static.foo");
        $res = $cb($req);
        like $res.field('Content-Type').Str, rx:i{'text/x-fooo' ';'?};
        is $res.code, 200;
    },
    app => $app;

done-testing;
