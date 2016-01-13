use v6;
use Test;
use Crust::Builder;
use IO::Blob;

subtest {
    my $app = builder {
        enable "AccessLog", format => "combined";
        enable "ContentLength";
        enable sub ($app) {
            return sub (%env) {
                my @res = $app(%env);
                @res[1].append("HELLO", "WORLD");
                return @res;
            }
        };
        sub (%env) { 200, [ 'Content-Type' => 'text/plain' ], [ 'Hello, World' ] };
    }

    my $io = IO::Blob.new;

    my %env = (
        :REMOTE_ADDR<127.0.0.1>,
        :HTTP_REFERER<http://www.example.com/start.html>,
        :REQUEST_METHOD<GET>,
        :REQUEST_URI</apache_pb.gif>,
        :SERVER_PROTOCOL<HTTP/1.1>,
        "p6sgi.errors" => $io,
    );

    my @res = $app(%env);
    $io.seek(0, SeekFromBeginning);
    my $s = $io.slurp-rest(:enc<ascii>);

    ok $s.starts-with('127.0.0.1 - - ['), "starts with 127.0.0.1";
    is @res[0], 200, "should be 200";
    is %(@res[1])<HELLO>, "WORLD";
    is %(@res[1])<Content-Length>, "Hello, World".encode.elems;
}, 'test for enable';

subtest {
    subtest {
        my $app = builder {
            enable-if -> %env { %env<REMOTE_ADDR> eq '127.0.0.1' }, "AccessLog", format => "combined";
            enable-if -> %env { %env<REMOTE_ADDR> eq '127.0.0.1' }, "ContentLength";
            enable-if -> %env { %env<REMOTE_ADDR> eq '127.0.0.1' }, sub ($app) {
                return sub (%env) {
                    my @res = $app(%env);
                    @res[1].append("HELLO", "WORLD");
                    return @res;
                }
            };
            sub (%env) { 200, [ 'Content-Type' => 'text/plain' ], [ 'Hello, World' ] };
        }

        my $io = IO::Blob.new;

        my %env = (
            :REMOTE_ADDR<127.0.0.1>,
            :HTTP_REFERER<http://www.example.com/start.html>,
            :REQUEST_METHOD<GET>,
            :REQUEST_URI</apache_pb.gif>,
            :SERVER_PROTOCOL<HTTP/1.1>,
            "p6sgi.errors" => $io,
        );

        my @res = $app(%env);
        $io.seek(0, SeekFromBeginning);
        my $s = $io.slurp-rest(:enc<ascii>);

        ok $s.starts-with('127.0.0.1 - - ['), "starts with 127.0.0.1";
        is @res[0], 200, "should be 200";
        is %(@res[1])<HELLO>, "WORLD";
        is %(@res[1])<Content-Length>, "Hello, World".encode.elems;
    }, 'Truely';

    subtest {
        my $app = builder {
            enable-if -> %env { %env<REMOTE_ADDR> eq '192.168.11.1' }, "AccessLog", format => "combined";
            enable-if -> %env { %env<REMOTE_ADDR> eq '192.168.11.1' }, "ContentLength";
            enable-if -> %env { %env<REMOTE_ADDR> eq '192.168.11.1' }, sub ($app) {
                return sub (%env) {
                    my @res = $app(%env);
                    @res[1].append("HELLO", "WORLD");
                    return @res;
                }
            };
            sub (%env) { 200, [ 'Content-Type' => 'text/plain' ], [ 'Hello, World' ] };
        }

        my $io = IO::Blob.new;

        my %env = (
            :REMOTE_ADDR<127.0.0.1>,
            :HTTP_REFERER<http://www.example.com/start.html>,
            :REQUEST_METHOD<GET>,
            :REQUEST_URI</apache_pb.gif>,
            :SERVER_PROTOCOL<HTTP/1.1>,
            "p6sgi.errors" => $io,
        );

        my @res = $app(%env);
        $io.seek(0, SeekFromBeginning);
        my $s = $io.slurp-rest(:enc<ascii>);

        is $s, '', 'empty logging';
        is @res[0], 200, "should be 200";
        nok %(@res[1])<HELLO>.defined;
        nok %(@res[1])<Content-Length>.defined;
    }, 'Falsy';
}, 'test for enable-if';

done-testing;

