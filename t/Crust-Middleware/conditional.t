use v6;
use Test;

use Crust::Test;
use Crust::Middleware::ContentLength;
use Crust::Middleware::Conditional;

subtest {
    my $app = sub (%env) {
        200, [], ['hello']
    };

    $app = Crust::Middleware::Conditional.new(
        $app,
        condition => -> %env {
            %env<PATH_INFO> eq '/foo/bar'
        },
        builder => -> $app {
            Crust::Middleware::ContentLength.new($app);
        },
    );

    {
        my @ret = $app((PATH_INFO => '/foo/bar'));
        is @ret[0], 200;
        is-deeply @ret[1], [:Content-Length('hello'.encode('ascii').elems)];
    }

    {
        my @ret = $app((PATH_INFO => '/'));
        is @ret[0], 200;
        is-deeply @ret[1], [];
    }
}, 'basic case';

done-testing;

