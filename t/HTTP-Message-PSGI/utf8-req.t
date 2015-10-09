use v6;
use Test;
use HTTP::Request;
use HTTP::Message::PSGI;
use URI::Escape;

BEGIN {
    # t/HTTP-Message-PSGI/utf8-req.t .. Could not parse URI: http://localhost/П
    # in block  at /Users/skaji/env/rakudobrew/moar-nom/install/share/perl6/site/lib/URI.pm:42
    print("1..0 # Skip: Known to fail\n");
    exit 0;
}

my @paths =
    'П', '%D0%9F',
    'À', '%C3%80',
;

for @paths -> $raw, $encoded {
    my $req = HTTP::Request.new(GET => "http://localhost/" ~ $raw);
    my $env = $req.to-psgi;
    is $env<REQUEST_URI>, "/$encoded";
    is $env<PATH_INFO>, uri_unescape("/$encoded");
}

done-testing;
