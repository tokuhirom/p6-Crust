use v6;
use Test;
use Crust::Builder;
use Crust::Test;

my %map = (
    :admin("s3cr3t"),
    :john("foo:bar"),
);
my $app = builder {
    enable "Auth::Basic",
        :authenticator(-> $u, $p, %env {
            %map{$u} && %map{$u} eq $p;
        });
    -> %env { 200, [:Content-Type('text/plain')], ["Hello {%env<REMOTE_USER>}!"] }
};

test-psgi
    app => $app,
    client => -> $cb {
        my ($req, $res);

        # No auth, should get 401
        $req = HTTP::Request.new(GET => "http://localhost/");
        $res = $cb($req);
        is $res.code, 401;

        # Auth for admin, should get 200
        $req = HTTP::Request.new(GET => "http://localhost/");
        $req.header.field(:Authorization('Basic YWRtaW46czNjcjN0'));
        $res = $cb($req);
        is $res.code, 200, "Should succeed";
        is $res.content.decode, "Hello admin!";

        # Auth for john, should get 200
        $req = HTTP::Request.new(GET => "http://localhost/");
        $req.header.field(:Authorization('Basic am9objpmb286YmFy'));
        $res = $cb($req);
        is $res.code, 200, "Should succeed";
        is $res.content.decode, "Hello john!";

        # Corrupt Authorization header, should get 401
        $req = HTTP::Request.new(GET => "http://localhost/");
        $req.header.field(:Authorization('Basic deadBEAFam9objpmb286YmFy'));
        $res = $cb($req);
        if !is $res.code, 401, "Should fail" {
            $res.content.decode.say;
        }
    }
;

done-testing;