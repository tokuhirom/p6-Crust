use v6;
use Crust::Test;
use Test;
use HTTP::Request;

$Crust::Test::Impl = "MockHTTP";

my $app = { 200, [], [ 'Hello' ] };

test-psgi $app, -> $cb {
    my $res = $cb(HTTP::Request.new(GET =>"/"));
    is $res.content, "Hello".encode;
};

done-testing;
