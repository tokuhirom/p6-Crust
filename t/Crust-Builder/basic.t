use v6;
use Test;
use Crust::Builder;
use Crust::Utils;
use IO::Blob;

my &app = builder -> {
    enable "AccessLog", format => "combined";
    enable "ContentLength";
    enable sub (&app) {
        return sub (%env) {
            my @res = &app(%env);
            @res[1].append("HELLO", "WORLD");
            return @res;
        }
    };
    sub (%env) { 200, [ "Content-Type" => "text/plain" ], [ "Hello, World" ] };
}

my $io = IO::Blob.new;

my %env = (
    :REMOTE_ADDR<127.0.0.1>,
    :HTTP_REFERER<http://www.example.com/start.html>,
    :REQUEST_METHOD<GET>,
    :REQUEST_URI</apache_pb.gif>,
    :SERVER_PROTOCOL<HTTP/1.1>,
    "p6sgi.error" => $io,
);

my @res = &app(%env);
$io.seek(0, 0);
my $s = $io.slurp-rest(:enc<ascii>);
if !ok $s ~~ /^ '127.0.0.1 - - [' /, "starts with 127.0.0.1" {
    return;
}

if !is @res[0], 200, "should be 200" {
    return;
}

if !is get-header(@res[1], "HELLO"), "WORLD" {
    return;
}

if !is get-header(@res[1], "Content-Length"), "Hello, World".chars {
    return;
}

done-testing;