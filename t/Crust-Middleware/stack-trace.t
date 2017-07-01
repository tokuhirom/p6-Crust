use v6;
use Test;

use Crust::Middleware::StackTrace;
use lib 't/lib/';
use SupplierBuffer;

my %env = (
    :REQUEST_METHOD<GET>,
    :SCRIPT_NAME<foobar>,
    :PATH_INFO</foo/bar>,
    :SERVER_NAME<server_name>,
    :SERVER_PORT<8080>,
    :SERVER_PROTOCOL<HTTP/1.1>,
);

subtest {
    my $buf = SupplierBuffer.new;

    temp %env = %env;
    %env<p6w.errors> = $buf.supplier;

    my $code = Crust::Middleware::StackTrace.new(
        sub (%env) {
            die 'Oops!';
        }
    );
    my $ret = await $code(%env);
    is $ret[0], 500;

    my $res-headers = $ret[1];
    is %$res-headers<Content-Type>, 'text/plain; charset=utf-8';

    is $ret[2].elems, 1;
    like $ret[2][0], rx{'in sub  at t/Crust-Middleware/stack-trace.t line ' \d+};

    like %env<crust.stacktrace.text>, rx{'in sub  at t/Crust-Middleware/stack-trace.t line ' \d+};
    like %env<crust.stacktrace.html>, rx{'Error:   in block  at ' \S+ ' line ' \d+};

    like $buf.result, rx{'in sub  at t/Crust-Middleware/stack-trace.t line ' \d+};
}, 'Errors with plain text trace';

subtest {
    my $buf = SupplierBuffer.new;

    temp %env = %env;
    %env<p6w.errors> = $buf.supplier;
    %env<HTTP_ACCEPT> = 'text/html';

    my $code = Crust::Middleware::StackTrace.new(
        sub (%env) {
            die 'Oops!';
        }
    );
    my $ret = await $code(%env);
    is $ret[0], 500;

    my $res-headers = $ret[1];
    is %$res-headers<Content-Type>, 'text/html; charset=utf-8';

    is $ret[2].elems, 1;
    like $ret[2][0], rx{'Error:' \s+ 'in block  at ' \S+ ' line ' \d+};

    like %env<crust.stacktrace.text>, rx{'in sub  at t/Crust-Middleware/stack-trace.t line 51'};
    like %env<crust.stacktrace.html>, rx{'Error:   in block  at ' \S+ ' line ' \d+};

    like $buf.result, rx{'in sub  at t/Crust-Middleware/stack-trace.t line ' \d+};
}, 'Errors with html trace';

subtest {
    my $buf = SupplierBuffer.new;

    temp %env = %env;
    %env<p6w.errors> = $buf.supplier;

    my $code = Crust::Middleware::StackTrace.new(
        sub (%env) {
            die 'Oops!';
        },
        no-print-errors => True,
    );
    my $ret = await $code(%env);
    is $ret[0], 500;

    is $buf.result, '';
}, 'Test for no-print-errors';

subtest {
    my $code = Crust::Middleware::StackTrace.new(
        sub (%env) {
            start { 200, [], ['hello'] }
        }
    );
    my $ret = await $code(%env);
    is $ret[0], 200;
    is $ret[1], [];
    is-deeply $ret[2], ['hello'];
}, 'No errors';

done-testing;

