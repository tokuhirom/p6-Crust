use v6;
use Crust::Test;
use Test;
use HTTP::Request;

$Crust::Test::Impl = "MockHTTP";

my $app = { start { 200, [], [ 'Hello' ] } };

test-p6w $app, -> $cb {
    my $res = $cb(HTTP::Request.new(GET =>"/"));
    is $res.content, "Hello".encode;
};

done-testing;
