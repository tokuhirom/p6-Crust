use v6;
unit class Crust::Test::MockHTTP;
use HTTP::Message::P6W;
use HTTP::Request;
use HTTP::Response;

has Callable $.app;

method request(HTTP::Request $req) {
    my $env = $req.to-p6w;
    $env<SERVER_NAME> ||= "localhost";

    my $res = try {
        my @res = await $!app($env);
        HTTP::Response.from-p6w(|@res)
    };
    unless $res {
        $res = HTTP::Response.from-p6w(500, [Content-Type => 'text/plain'], [ $!.Str ]);
    }

    $res.request = $req;
    $res;
}
