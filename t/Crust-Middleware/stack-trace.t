use v6;
use Test;

use IO::Blob;
use Crust::Middleware::StackTrace;

my %env = (
    :REQUEST_METHOD<GET>,
    :SCRIPT_NAME<foobar>,
    :PATH_INFO</foo/bar>,
    :SERVER_NAME<server_name>,
    :SERVER_PORT<8080>,
    :SERVER_PROTOCOL<HTTP/1.1>,
);

subtest {
    my $io = IO::Blob.new;

    temp %env = %env;
    %env<p6sgi.errors> = $io;

    my $code = Crust::Middleware::StackTrace.new(
        sub (%env) {
            die 'Oops!';
        }
    );
    my $ret = $code(%env);
    is $ret[0], 500;

    my $res-headers = $ret[1];
    is %$res-headers<Content-Type>, 'text/plain; charset=utf-8';

    is $ret[2].elems, 1;
    like $ret[2][0], rx{'in block <unit> at t/Crust-Middleware/stack-trace.t line 16'};

    like %env<crust.stacktrace.text>, rx{'in block <unit> at t/Crust-Middleware/stack-trace.t line 16'};
    like %env<crust.stacktrace.html>, rx{'Error:' \s+ 'in block &lt;unit&gt; at t/Crust-Middleware/stack-trace.t line 16'};

    $io.seek(0, SeekFromBeginning); # rewind
    like $io.slurp-rest, rx{'in block <unit> at t/Crust-Middleware/stack-trace.t line 16'};
}, 'Errors with plain text trace';

subtest {
    my $io = IO::Blob.new;

    temp %env = %env;
    %env<p6sgi.errors> = $io;
    %env<HTTP_ACCEPT> = 'text/html';

    my $code = Crust::Middleware::StackTrace.new(
        sub (%env) {
            die 'Oops!';
        }
    );
    my $ret = $code(%env);
    is $ret[0], 500;

    my $res-headers = $ret[1];
    is %$res-headers<Content-Type>, 'text/html; charset=utf-8';

    is $ret[2].elems, 1;
    like $ret[2][0], rx{'Error:' \s+ 'in block &lt;unit&gt; at t/Crust-Middleware/stack-trace.t line 43'};

    like %env<crust.stacktrace.text>, rx{'in block <unit> at t/Crust-Middleware/stack-trace.t line 43'};
    like %env<crust.stacktrace.html>, rx{'Error:' \s+ 'in block &lt;unit&gt; at t/Crust-Middleware/stack-trace.t line 43'};

    $io.seek(0, SeekFromBeginning); # rewind
    like $io.slurp-rest, rx{'in block <unit> at t/Crust-Middleware/stack-trace.t line 43'};
}, 'Errors with html trace';

subtest {
    my $io = IO::Blob.new;

    temp %env = %env;
    %env<p6sgi.errors> = $io;

    my $code = Crust::Middleware::StackTrace.new(
        sub (%env) {
            die 'Oops!';
        },
        no-print-errors => True,
    );
    my $ret = $code(%env);
    is $ret[0], 500;

    $io.seek(0, SeekFromBeginning); # rewind
    is $io.slurp-rest, '';
}, 'Test for no-print-errors';

subtest {
    my $code = Crust::Middleware::StackTrace.new(
        sub (%env) {
            200, [], ['hello']
        }
    );
    my $ret = $code(%env);
    is $ret[0], 200;
    is $ret[1], [];
    is-deeply $ret[2], ['hello'];
}, 'No errors';

done-testing;

