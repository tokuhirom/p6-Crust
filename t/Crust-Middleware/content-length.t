use v6;
use Test;

use Crust::Middleware::ContentLength;

my %env = (
    :REQUEST_METHOD<GET>,
    :SCRIPT_NAME<foobar>,
    :PATH_INFO</foo/bar>,
    :SERVER_NAME<server_name>,
    :SERVER_PORT<8080>,
    :SERVER_PROTOCOL<HTTP/1.1>
);

subtest {
    my $code = Crust::Middleware::ContentLength.new(
        sub (%env) {
            200, [], [
                'hello',
                'goodbye',
            ]
        }
    );

    my @ret = $code(%env);

    is @ret[0], 200;
    is-deeply @ret[1], [{Content-Length => 12}];
}, 'Calc Content-Length by Blob';

subtest {
    my $code = Crust::Middleware::ContentLength.new(
        sub (%env) {
            200, [], ['hello', 'goodbye']
        }
    );

    my @ret = $code(%env);

    is @ret[0], 200;
    is-deeply @ret[1], [{Content-Length => 12}];
}, 'Calc Content-Length by Str';

subtest {
    my $io = $*PROGRAM.open;

    my $code = Crust::Middleware::ContentLength.new(
        sub (%env) {
            200, [], $io,
        }
    );

    my @ret = $code(%env);

    is @ret[0], 200;
    say @ret[1];
    # is-deeply @ret[1], [{Content-Length => 12}];

    $io.close;
}, 'Calc Content-Length by IO::Handle';

subtest {
    my $code = Crust::Middleware::ContentLength.new(
        sub (%env) {
            100, [], ['hello', 'goodbye']
        }
    );

    my @ret = $code(%env);

    is @ret[0], 100;
    is-deeply @ret[1], [];
}, 'Should not add Content-Length because status is not suitable';

subtest {
    my $code = Crust::Middleware::ContentLength.new(
        sub (%env) {
            200, [Content-Length => 10000], ['hello', 'goodbye']
        }
    );

    my @ret = $code(%env);

    is @ret[0], 200;
    is-deeply @ret[1], [{Content-Length => 10000}];
}, 'Content-Length has already set';

subtest {
    my $code = Crust::Middleware::ContentLength.new(
        sub (%env) {
            200, [Transfer-Encoding => 'chunked'], ['hello', 'goodbye']
        }
    );

    my @ret = $code(%env);

    is @ret[0], 200;
    is-deeply @ret[1], [{Transfer-Encoding => 'chunked'}];
}, 'Should not add Content-Length because Transfer-Encoding is set';

subtest {
    # XXX maybe invalid response body type...
    {
        my $code = Crust::Middleware::ContentLength.new(
             sub (%env) {
                200, [], Nil
            }
        );

        my @ret = $code(%env);

        is @ret[0], 200;
        is-deeply @ret[1], [];
    }

    {
        my $code = Crust::Middleware::ContentLength.new(
            sub (%env) {
                200, [], 42
            }
        );

        my @ret = $code(%env);

        is @ret[0], 200;
        is-deeply @ret[1], [];
    }
}, 'Should not add Content-Length because response body is not supported type';

done-testing;

