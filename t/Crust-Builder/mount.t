use v6;
use Test;
use Crust::Builder;
use Crust::Test;
use HTTP::Request;

subtest {
    my $app = sub ($env) {
        start { 200, [ 'Content-Type' => 'text/plain' ], [ 'Hello, World' ] }
    };

    my $builder = builder {
        mount "/foo", builder {
            enable "ContentLength";
            enable sub ($app) {
                return sub (%env) {
                    start {
                        my @res = await $app(%env);
                        @res[1].append("HELLO", "WORLD");
                        @res;
                    };
                }
            };
            $app;
        };
        mount "/bar", builder {
            enable "ContentLength";
            $app;
        };
    };

    test-p6w
        client => -> $cb {
            my $req = HTTP::Request.new(
                GET => '/foo',
            );
            my $res = $cb($req);
            is $res.code, 200;

            my $header = $res.header;
            is-deeply $header.field('HELLO').values, ['WORLD'];
            is-deeply $header.field('Content-Length').values, ["Hello, World".encode.elems];
        },
        app => $builder;

    test-p6w
        client => -> $cb {
            my $req = HTTP::Request.new(
                GET => '/bar',
            );
            my $res = $cb($req);
            is $res.code, 200;

            my $header = $res.header;
            ok !$header.field('HELLO').defined;
            is-deeply $header.field('Content-Length').values, ["Hello, World".encode.elems];
        },
        app => $builder;
}, 'test for mount';

done-testing;

