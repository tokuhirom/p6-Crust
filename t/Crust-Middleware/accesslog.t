use v6;
use Test;

use Crust::Middleware::AccessLog;
use IO::Blob;

{
    my $io = IO::Blob.new;
    my %env = (
        :REMOTE_ADDR<127.0.0.1>,
        :HTTP_REFERER<http://www.example.com/start.html>,
        :REQUEST_METHOD<GET>,
        :REQUEST_URI</apache_pb.gif>,
        :SERVER_PROTOCOL<HTTP/1.1>,
        'p6sgi.error' => $io
    );
    my $code = Crust::Middleware::AccessLog.new(
        app => sub (%env) {
            404, [], ['hello'.encode('ascii')]
        }
    );
    $code(%env);
    $io.seek(0,0); # rewind
    my $got = $io.slurp-rest(:enc<ascii>);
    ok $got ~~ /^ '127.0.0.1 - - [' /;
    ok $got.index('] "GET /apache_pb.gif HTTP/1.1" 404 - "http://www.example.com/start.html" "-"') > 0;
    note "# " ~ $got;
}


done-testing;

