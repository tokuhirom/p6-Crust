use v6;
unit class Crust::Test::MockHTTP;
use HTTP::Message::PSGI;
use HTTP::Request;
use HTTP::Response;

has Callable $.app;

method request(HTTP::Request $req) {
    my $env = $req.to-psgi;
    $env<SERVER_NAME> ||= "localhost";

    my $res = try {
        my @res = $!app($env).result;
        HTTP::Response.from-psgi(|@res)
    };
    unless $res {
        $res = HTTP::Response.from-psgi(500, [Content-Type => 'text/plain'], [ $!.Str ]);
    }

    $res.request = $req;
    $res;
}
