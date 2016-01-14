use v6;
unit class HTTP::Message::PSGI;

use HTTP::Response;
use HTTP::Request;
use URI::Escape;
use IO::Blob;
use URI;

our sub req-to-psgi($req, *%args) {
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
        'p6sgi.version'      => [ 1, 1 ],
        'p6sgi.url-scheme'   => $uri.scheme eq 'https' ?? 'https' !! 'http',
        'p6sgi.input'        => $input,
        'p6sgi.errors'       => $*ERR,
        'p6sgi.multithread'  => False,
        'p6sgi.multiprocess' => False,
        'p6sgi.run_once'     => True,
        'p6sgi.streaming'    => True,
        'p6sgi.nonblocking'  => False,
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
        my $len = $env<p6sgi.input>.data.elems;
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

our sub res-from-psgi(Int $status, Array $headers, $body) {
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
    HTTP::Request.^add_method: 'to-psgi', method (HTTP::Request:D:) {
        req-to-psgi(self);
    };

    HTTP::Response.^add_method: 'from-psgi', method (
        HTTP::Response:U: Int $status, Array $headers, $body) {
        res-from-psgi($status, $headers, $body);
    };
}

=begin pod

=head1 NAME

HTTP::Message::PSGI - Converts HTTP::Request and HTTP::Response from/to PSGI env and response

=head1 SYNOPSIS

  use HTTP::Message::PSGI;
  use HTTP::Request;

  my $req = HTTP::Request.new(GET => "http://example.com/foo");
  my $psgi-env = $req.to-psgi;

  my $psgi-res = 200, ['Content-Type' => 'text/plain'], ['ok'];
  my $res = HTTP::Response.from-psgi(|$psgi-res);

=head1 DESCRIPTION

HTTP::Message::PSGI is perl6 port of perl5 HTTP::Message::PSGI.

HTTP::Message::PSGI gives you convenient methods to convert an L<HTTP::Request>
object to a PSGI env hash and convert a PSGI response arrayref to
a L<HTTP::Response> object.

=head1 AUTHOR

Shoichi Kaji

=head1 ORIGINAL AUTHOR

This file is port of Plack's HTTP::Message::PSGI written by Tatsuhiko Miyagawa

=end pod
