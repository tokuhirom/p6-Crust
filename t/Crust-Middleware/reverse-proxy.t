use v6;
use Test;
use Crust::Test;
use Crust::Request;
use HTTP::Request;

use Crust::Middleware::ReverseProxy;

sub run(Str $tag, %arg) {
    my %input = %arg<input>.lines.map({|.split(rx{':' ' '?}, 2)});

    test-psgi
        client => -> $cb {
            my $req = HTTP::Request.new(
                GET => 'http://example.com/?foo=bar',
                |%input,
            );

            # FIXME [WORKAROUND] overwrite http header 'Host'
            # https://github.com/sergot/http-useragent/issues/85
            if %input.keys.first({.lc eq "host"}) -> $host {
                $req.field(Host => %input{$host});
            }

            $cb($req);
        },
        app => -> %env {
            my $code = Crust::Middleware::ReverseProxy.new(
                sub (%env) {
                    my $req = Crust::Request.new(%env);

                    if %arg<address>.defined {
                        is $req.address, %arg<address>, "$tag of address";
                    }

                    if %arg<secure>.defined {
                        is ($req.env<p6sgi.url_scheme> eq 'https'), %arg<secure>, "$tag of secure";
                    }

                    for qw/uri base/ -> $url {
                        if %arg{$url}.defined {
                            is $req."$url"(), %arg{$url}, "$tag of $url";
                        }
                    }

                    return 200, ['Content-Type' => 'text/plain'], [ 'OK' ];
                }
            );
            $code(%env);
        };
}

my @tests = [
    'with https' => {
        input  => q{x-forwarded-https: on},
        secure => True,
        base   => 'https://example.com/',
        uri    => 'https://example.com/?foo=bar'
    },
    'without https' => {
        input  => q{x-forwarded-https: off},
        secure => False,
        base   => 'http://example.com/',
        uri    => 'http://example.com/?foo=bar'
    },
    'dummy' => {
        input  => q{dummy: 1},
        secure => False,
        base   => 'http://example.com/',
        uri    => 'http://example.com/?foo=bar',
    },
    'https with HTTP_X_FORWARDED_PROTO' => {
        input  => q{x-forwarded-proto: https},
        secure => True,
        base   => 'https://example.com/',
        uri    => 'https://example.com/?foo=bar'
    },
    'http with HTTP_X_FORWARDED_PROTO' => {
        input  => q{x-forwarded-proto: http},
        secure => False,
        base   => 'http://example.com/',
        uri    => 'http://example.com/?foo=bar',
    },
    'with HTTP_X_FORWARDED_FOR' => {
        input   => q{x-forwarded-for: 192.168.3.2},
        address => '192.168.3.2',
        base    => 'http://example.com/',
        uri     => 'http://example.com/?foo=bar',
    },
    'with HTTP_X_FORWARDED_HOST' => {
        input => q{x-forwarded-host: 192.168.1.2:5235},
        base  => 'http://192.168.1.2:5235/',
        uri   => 'http://192.168.1.2:5235/?foo=bar',
    },
    'default port with HTTP_X_FORWARDED_HOST' => {
        input => q{x-forwarded-host: 192.168.1.2},
        base  => 'http://192.168.1.2/',
        uri   => 'http://192.168.1.2/?foo=bar',
    },
    'default https port with HTTP_X_FORWARDED_HOST' => {
        input => q{x-forwarded-https: on
x-forwarded-host: 192.168.1.2},
        base  => 'https://192.168.1.2/',
        uri   => 'https://192.168.1.2/?foo=bar',
    },
    'default port with HOST' => {
        input => q{host: 192.168.1.2},
        base  => 'http://192.168.1.2/',
        uri   => 'http://192.168.1.2/?foo=bar',
    },
    'default https port with HOST' => {
        input => q{host: 192.168.1.2
https: ON},
        base  => 'https://192.168.1.2/',
        uri   => 'https://192.168.1.2/?foo=bar',
    },
    'with HTTP_X_FORWARDED_HOST and HTTP_X_FORWARDED_PORT' => {
        input => q{x-forwarded-host: 192.168.1.5
x-forwarded-port: 1984},
        base  => 'http://192.168.1.5:1984/',
        uri   => 'http://192.168.1.5:1984/?foo=bar',
    },
    'with multiple HTTP_X_FORWARDED_HOST and HTTP_X_FORWARDED_FOR' => {
        input   => q{x-forwarded-host: outmost.proxy.example.com, middle.proxy.example.com
x-forwarded-for: 1.2.3.4, 192.168.1.6
host: 192.168.1.7:5000},
        address => '192.168.1.6',
        base    => 'http://middle.proxy.example.com/',
        uri     => 'http://middle.proxy.example.com/?foo=bar',
    },
    'normal plackup status' => {
        input => q{host: 127.0.0.1:5000},
        base  => 'http://127.0.0.1:5000/',
        uri   => 'http://127.0.0.1:5000/?foo=bar',
    },
    'HTTP_X_FORWARDED_PORT to secure port' => {
        input  => q{x-forwarded-host: 192.168.1.2
x-forwarded-port: 443},
        secure => True,
    },
    'HTTP_X_FORWARDED_PORT to secure port (apache2)' => {
        input  => q{x-forwarded-server: proxy.example.com
x-forwarded-host: proxy.example.com:8443
x-forwarded-https: on
x-forwarded-port: 8443},
        base   => 'https://proxy.example.com:8443/',
        uri    => 'https://proxy.example.com:8443/?foo=bar',
        secure => True,
    },
    'with HTTP_X_FORWARDED_SERVER including 443 port (apache1)' => {
        input  => q{x-forwarded-server: proxy.example.com:443
x-forwarded-host: proxy.example.com},
        base   => 'https://proxy.example.com/',
        uri    => 'https://proxy.example.com/?foo=bar',
        secure => True,
    }
];

for @tests -> Pair $test {
    my ($tag, %test) = $test.kv;
    run($tag, %test);
}

subtest {
    subtest {
        my %input = (x-forwarded-for => q{I'm not a IP address});

        test-psgi
            client => -> $cb {
                my $req = HTTP::Request.new(
                    GET => 'http://example.com/?foo=bar',
                    |%input,
                );
                my $res = $cb($req);
                is $res.code, 500;
                like $res.content.decode, /^'Invalid remote address has come'/;
            },
            app => -> %env {
                my $code = Crust::Middleware::ReverseProxy.new(
                    sub (%env) {
                        my $req = Crust::Request.new(%env);
                        return 200, ['Content-Type' => 'text/plain'], [ 'OK' ];
                    },
                );
                $code(%env);
            };
    }, 'Invalid ip';

    subtest {
        my %input = (x-forwarded-for => '1.1.1.1');

        test-psgi
            client => -> $cb {
                my $req = HTTP::Request.new(
                    GET => 'http://example.com/?foo=bar',
                    |%input,
                );
                my $res = $cb($req);
                is $res.code, 500;
                like $res.content.decode, /^'Invalid remote address has come'/;
            },
            app => -> %env {
                my $code = Crust::Middleware::ReverseProxy.new(
                    sub (%env) {
                        my $req = Crust::Request.new(%env);
                        return 200, ['Content-Type' => 'text/plain'], [ 'OK' ];
                    },
                    ip-pattern => rx{'127.0.0.1'},
                );
                $code(%env);
            };
    }, 'Specify own pattern';

    subtest {
        my %input = (x-forwarded-for => q{I'm not a IP address});

        test-psgi
            client => -> $cb {
                my $req = HTTP::Request.new(
                    GET => 'http://example.com/?foo=bar',
                    |%input,
                );
                my $res = $cb($req);
                is $res.code, 200;
            },
            app => -> %env {
                my $code = Crust::Middleware::ReverseProxy.new(
                    sub (%env) {
                        my $req = Crust::Request.new(%env);
                        return 200, ['Content-Type' => 'text/plain'], [ 'OK' ];
                    },
                    ip-pattern => Nil,
                );
                $code(%env);
            };
    }, 'Ignore invalid IP';
}, 'Test for validate REMOTE_ADDR';

done-testing;

