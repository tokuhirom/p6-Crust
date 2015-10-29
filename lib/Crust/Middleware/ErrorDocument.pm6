use v6;

use Crust::Middleware;
use Crust::MIME;
use HTTP::Status;

unit class Crust::Middleware::ErrorDocument is Crust::Middleware;

has Hash $.errors;
has Bool $.sub-request;

method new(Callable $app, |opts) {
    my %newopts = errors => {}, sub-request => False;
    for opts -> $opt {
        my $kv = $opt.key ~~ Pair ?? $opt.key !! $opt;
        if $kv.key eq 'sub-request' {
            %newopts<sub-request> = $kv.value;
        } else {
            %newopts<errors>{$kv.key.Str} = $kv.value;
        }
    }
    callwith($app, |%newopts);
}

method CALL-ME(%env) {
    my @ret = $.app()(%env);

    my %headers = %(@ret[1]);
    my $path = $!errors{@ret[0].Str};
    if !is-error(@ret[0]) || !$path.defined {
        return @ret;
    }
    if $!sub-request {
        for %headers -> $pair {
            unless ($pair.key ~~ /^ psgi /) {
                %headers{'p6sgix.errordocument.' ~ $pair.key} = $pair.value;
            }
        }
        %env<REQUEST_METHOD> = 'GET';
        %env<REQUEST_URI>    = $path;
        %env<PATH_INFO>      = $path;
        %env<QUERY_STRING>   = '';
        %env<CONTENT_LENGTH>:delete;

        my @sub_ret = $.app()(%env);
        @ret = @sub_ret if @sub_ret[0] == 200;
    } else {
        %headers<Content-Length>:delete;
        %headers<Content-Encoding>:delete;
        %headers<Transfer-Encoding>:delete;
        %headers<Content-Type> = Crust::MIME.mime-type($path);

        @ret[2] = open $path, :bin;
    }

    @ret[1] = [%headers];

    return @ret;
}


=begin pod

=head1 NAME

Crust::Middleware::ErrorDocument - Set Error Document based on HTTP status code

=head1 SYNOPSIS

  my &app = sub(%env) { ... };
  my $code = Crust::Middleware::ErrorDocument.new(
    &app,
    500 => '/uri/error/500.html',
    404 => '/uri/error/404.html',
  }

  # getting sub request
  $code = Crust::Middleware::ErrorDocument.new(
    &app,
    500 => '/uri/error/500.html',
    404 => '/uri/error/404.html',
    :sub-request => True,
  }

=end pod

