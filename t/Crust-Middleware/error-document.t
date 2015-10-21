use v6;
use Test;
use Crust::Middleware::ErrorDocument;
use File::Temp;

my $tempdir = tempdir;
"$tempdir/500.html".IO.spurt: q:to/EOF/;
INTERNAL SERVER ERROR!
EOF
"$tempdir/404.png".IO.spurt: q:to/EOF/;
NOT FOUND!
EOF

my %env = (
    :REQUEST_METHOD<GET>,
    :SCRIPT_NAME<foobar>,
    :PATH_INFO</foo/bar>,
    :SERVER_NAME<server_name>,
    :SERVER_PORT<8080>,
    :SERVER_PROTOCOL<HTTP/1.1>
);

subtest {
    my $app = Crust::Middleware::ErrorDocument.new(
        sub (%env) {
            200, ['Content-Type' => 'text/plain'], ['OK']
        },
        errors => { 500 => "$tempdir/500.html", 404 => "$tempdir/404.png" }
    );
    my @ret = $app(%env);

    is @ret[0], 200;
    is-deeply @ret[1], [:Content-Type('text/plain')];
    is-deeply @ret[2], ["OK"];
}, 'Status 200';

subtest {
    my $app = Crust::Middleware::ErrorDocument.new(
        sub (%env) {
            404, ['Content-Type' => 'text/plain'], ['OK']
        },
        errors => { 500 => "$tempdir/500.html", 404 => "$tempdir/404.png" }
    );
    my @ret = $app(%env);

    is @ret[0], 404;
    is-deeply @ret[1], [:Content-Type('image/png')];
    isa-ok @ret[2], IO::Handle;
}, 'Status 404';

subtest {
    my $app = Crust::Middleware::ErrorDocument.new(
        sub (%env) {
            500, ['Content-Type' => 'text/plain'], ['OK']
        },
        errors => { 500 => "$tempdir/500.html", 404 => "$tempdir/404.png" }
    );
    my @ret = $app(%env);

    is @ret[0], 500;
    is-deeply @ret[1], [:Content-Type('text/html')];
    isa-ok @ret[2], IO::Handle;
}, 'Status 500';

subtest {
    my $app = Crust::Middleware::ErrorDocument.new(
        sub (%env) {
            500, ['Content-Type' => 'text/plain'], ['OK']
        },
        errors => { 500 => "$tempdir/500.html", 404 => "$tempdir/404.png" },
        sub-request => True
    );
    my @ret = $app(%env);

    is @ret[0], 500;
    is-deeply @ret[1], [:Content-Type('text/plain'), 'psgix.errordocument.Content-Type' => 'text/plain'];
    isa-ok @ret[2], Array;
}, 'Sub Request';

done-testing;
