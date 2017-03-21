use v6;
use Test;

use Crust::Middleware::AccessLog;
use IO::Blob;

my &hello-app = sub (%env) {
    404, [], ['hello']
}

sub make-check-combined-logs($io) {
    return sub {
        $io.seek(0, SeekFromBeginning); # rewind
        my $s = $io.slurp-rest(:enc<ascii>);
        if ! ok($s.defined, "\$s is defined") {
            note $s;
            return;
        }

        ok $s ~~ /^ '127.0.0.1 - - [' /, "starts with 127.0.0.1";
        my $v = $s.index('] "GET /apache_pb.gif HTTP/1.1" 404 - "http://www.example.com/start.html" "-"');
        if ! ok($v.defined, "\$v is defined") {
            note $s;
            return;
        }
        ok($v > 0);
        note "# " ~ $s if %*ENV<TEST_VERBOSE>;
    }
}

sub runit (&app, &checker, %extra-env?) {
    my $io = IO::Blob.new;
    my %env = (
        :REMOTE_ADDR<127.0.0.1>,
        :HTTP_REFERER<http://www.example.com/start.html>,
        :REQUEST_METHOD<GET>,
        :REQUEST_URI</apache_pb.gif>,
        :SERVER_PROTOCOL<HTTP/1.1>,
    );

    if %extra-env.defined {
        %env = (|%env, |%extra-env);
    }
    &app(%env);
    &checker();
}

{
    my $io = IO::Blob.new;
    my &code = Crust::Middleware::AccessLog.new(&hello-app);
    runit(&code, make-check-combined-logs($io), ("p6sgi.errors" => $io));
}

{
    my $io = IO::Blob.new;
    my &code = Crust::Middleware::AccessLog.new(
        &hello-app,
        format => "combined",
    );
    runit(&code, make-check-combined-logs($io), ("p6sgi.errors" => $io));
}

{
    my $io = IO::Blob.new;
    my &code = Crust::Middleware::AccessLog.new(
        &hello-app,
        format => Nil,
    );
    runit(&code, make-check-combined-logs($io), ("p6sgi.errors" => $io));
}

{
    my $io = IO::Blob.new;
    my &code = Crust::Middleware::AccessLog.new(
        &hello-app,
        format => "",
    );
    runit(&code, make-check-combined-logs($io), ("p6sgi.errors" => $io));
}

{
    my $io = IO::Blob.new;
    my &code = Crust::Middleware::AccessLog.new(
        &hello-app,
        format => Nil,
        logger => sub { my $s = shift @_; $io.print($s) },
    );
    runit(&code, make-check-combined-logs($io));
}


done-testing;

