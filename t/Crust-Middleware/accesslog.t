use v6;
use Test;

use Crust::Middleware::AccessLog;
use lib 't/lib/';
use SupplierBuffer;

my &hello-app = sub (%env) {
    start { 404, [], ['hello'] }
}

sub make-check-combined-logs($buf) {
    return sub {
        my $s = $buf.result();
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
    await &app(%env);
    &checker();
}

{
    my $buf = SupplierBuffer.new;
    my &code = Crust::Middleware::AccessLog.new(&hello-app);
    runit(&code, make-check-combined-logs($buf), ("p6w.errors" => $buf.supplier));
}

{
    my $buf = SupplierBuffer.new;
    my &code = Crust::Middleware::AccessLog.new(
        &hello-app,
        format => "combined",
    );
    runit(&code, make-check-combined-logs($buf), ("p6w.errors" => $buf.supplier));
}

{
    my $buf = SupplierBuffer.new;
    my &code = Crust::Middleware::AccessLog.new(
        &hello-app,
        format => Nil,
    );
    runit(&code, make-check-combined-logs($buf), ("p6w.errors" => $buf.supplier));
}

{
    my $buf = SupplierBuffer.new;
    my &code = Crust::Middleware::AccessLog.new(
        &hello-app,
        format => "",
    );
    runit(&code, make-check-combined-logs($buf), ("p6w.errors" => $buf.supplier));
}

{
    my $buf = SupplierBuffer.new;
    my &code = Crust::Middleware::AccessLog.new(
        &hello-app,
        format => Nil,
        logger => sub { my $s = shift @_; $buf.supplier.emit($s) },
    );
    runit(&code, make-check-combined-logs($buf));
}


done-testing;

