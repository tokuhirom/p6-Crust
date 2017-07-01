use v6;
unit class HTTP::Message::P6W;

use HTTP::Response;
use HTTP::Request;
use URI::Escape;
use IO::Blob;
use URI;

sub supplier-for-io(IO::Handle $io --> Supplier) {
    my $supplier = Supplier.new;
    my $supply = $supplier.Supply;
    $supply.tap(-> $v { $io.say($v) });
    return $supplier;
}

our sub req-to-p6w($req, *%args) {
    my $uri = $req.uri;
    my IO::Blob $input .= new(
        ( $req.content ~~ Str ?? $req.content.encode !! $req.content ) || "".encode
    );

    my $env = {
        PATH_INFO         => uri_unescape($uri.path || '/'),
        QUERY_STRING      => $uri.query || '',
        SCRIPT_NAME       => '',
        SERVER_NAME       => $uri.host,
        SERVER_PORT       => $uri.port,
        SERVER_PROTOCOL   => $req.protocol || 'HTTP/1.1',
        REMOTE_ADDR       => '127.0.0.1',
        REMOTE_HOST       => 'localhost',
        REMOTE_PORT       => 64000.rand.Int + 1000,                   # not in RFC 3875
        REQUEST_URI       => $uri.path_query || '/',                  # not in RFC 3875
        REQUEST_METHOD    => $req.method,
        'p6w.version'      => Version.new("0.7.Draft"),
        'p6w.url-scheme'   => $uri.scheme eq 'https' ?? 'https' !! 'http',
        'p6w.input'        => $input,
        'p6w.errors'       => supplier-for-io($*ERR),
        'p6w.multithread'  => False,
        'p6w.multiprocess' => False,
        'p6w.run_once'     => True,
        'p6w.streaming'    => True,
        'p6w.nonblocking'  => False,
        |%args,
    };

    for $req.header.header-field-names -> $field {
        my $key = "HTTP_$field".uc;
        $key ~~ s:g/'-'/_/;
        $key ~~ s/^HTTP_// if $field ~~ /^ Content '-' [Length|Type] $/;
        unless $env{$key}:exists {
            $env{$key} = $req.field($field).Str;
        }
    }
    unless $env<CONTENT_LENGTH>:exists {
        my $len = $env<p6w.input>.data.elems;
        $env<CONTENT_LENGTH> = $len;
    }

    if $env<SCRIPT_NAME> {
        $env<PATH_INFO> ~~ s/^ "$env<SCRIPT_NAME>" /\//;
        $env<PATH_INFO> ~~ s/^\/+/\//;
    }

    if !$env<HTTP_HOST>.defined && $req.uri.host {
        $env<HTTP_HOST> = $req.uri.host || "";
        $env<HTTP_HOST> ~= ':' ~ $req.uri.port if $req.uri.port != $req.uri.default_port;
    }

    return $env;
}

our sub res-from-p6w(Int $status, Array $headers, $body) {
    my $res = HTTP::Response.new($status);
    my @http-headers;
    for @($headers) -> $header {
        # TODO support multiple value
        $res.field(|$header);
    }
    my Buf $buf .= new;
    if $body ~~ Array {
        for @($body) -> $elem {
            $buf ~= $elem ~~ Str ?? $elem.encode !! $elem;
        }
    } elsif $body ~~ IO::Handle {
        until $body.eof {
            $buf ~= $body.read(1024);
        }
        $body.close;
    } elsif $body ~~ Channel {
        while my $got = $body.receive {
            $buf ~= $got;
        }
        CATCH { when X::Channel::ReceiveOnClosed { } }
    } else {
        die "3rd element of response object must be instance of Array or IO::Handle or Channel";
    }
    $res.content = $buf;
    $res;
}

BEGIN {
    # https://rt.perl.org/Public/Bug/Display.html?id=126341
    # per above ticket, add_method must be inside a BEGIN block
    HTTP::Request.^add_method: 'to-p6w', method (HTTP::Request:D:) {
        req-to-p6w(self);
    };

    HTTP::Response.^add_method: 'from-p6w', method (
        HTTP::Response:U: Int $status, Array $headers, $body) {
        res-from-p6w($status, $headers, $body);
    };
}

=begin pod

=head1 NAME

HTTP::Message::P6W - Converts HTTP::Request and HTTP::Response from/to P6W env and response

=head1 SYNOPSIS

  use HTTP::Message::P6W;
  use HTTP::Request;

  my $req = HTTP::Request.new(GET => "http://example.com/foo");
  my $p6w-env = $req.to-p6w;

  my $p6w-res = 200, ['Content-Type' => 'text/plain'], ['ok'];
  my $res = HTTP::Response.from-p6w(|$p6w-res);

=head1 DESCRIPTION

HTTP::Message::P6W is perl6 port of perl5 HTTP::Message::PSGI.

HTTP::Message::P6W gives you convenient methods to convert an L<HTTP::Request>
object to a P6W env hash and convert a P6W response arrayref to
a L<HTTP::Response> object.

=head1 AUTHOR

Shoichi Kaji

=head1 ORIGINAL AUTHOR

This file is port of Plack's HTTP::Message::PSGI written by Tatsuhiko Miyagawa

=end pod
