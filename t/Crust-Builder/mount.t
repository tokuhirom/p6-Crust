use v6;
use Test;
use Crust::Builder;
use Crust::Test;

subtest {
    my $app = sub ($env) {
        200, [ 'Content-Type' => 'text/plain' ], [ 'Hello, World' ]
    };

    my $builder = builder {
        mount "/foo", builder {
            enable "ContentLength";
            enable sub ($app) {
                return sub (%env) {
                    my @res = $app(%env);
                    @res[1].append("HELLO", "WORLD");
                    return @res;
                }
            };
            $app;
        };
        mount "/bar", builder {
            enable "ContentLength";
            $app;
        };
    };

    test-psgi
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

    test-psgi
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

