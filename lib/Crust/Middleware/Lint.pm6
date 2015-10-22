use v6;
use Crust::Middleware;

unit class Crust::Middleware::Lint is Crust::Middleware;

my sub validate-env(%env) {
    unless %env<REQUEST_METHOD> {
        die 'Missing env param: REQUEST_METHOD';
    }
    unless %env<REQUEST_METHOD> ~~ /^<[A..Z]>+$/ {
        die "Invalid env param: REQUEST_METHOD(%env<REQUEST_METHOD>)";
    }
    unless %env<SCRIPT_NAME>.defined { # allows empty string
        die 'Missing mandatory env param: SCRIPT_NAME';
    }
    if %env<SCRIPT_NAME> eq '/' {
        die 'SCRIPT_NAME must not be /';
    }
    unless %env<PATH_INFO>.defined { # allows empty string
        die 'Missing mandatory env param: PATH_INFO';
    }
    if %env<PATH_INFO> ne '' && %env<PATH_INFO> !~~ m!^'/'! {
        die "PATH_INFO must begin with / (%env<PATH_INFO>)";
    }
    unless %env<SERVER_NAME>.defined {
        die 'Missing mandatory env param: SERVER_NAME';
    }
    if %env<SERVER_NAME> eq '' {
        die 'SERVER_NAME must not be empty string';
    }
    unless %env<SERVER_PORT>.defined {
        die 'Missing mandatory env param: SERVER_PORT';
    }
    if %env<SERVER_PORT> eq '' {
        die 'SERVER_PORT must not be empty string';
    }
    if %env<SERVER_PROTOCOL>.defined && %env<SERVER_PROTOCOL> !~~ m{^HTTP'/'\d} {
        die "Invalid SERVER_PROTOCOL: %env<SERVER_PROTOCOL>";
    }

    # TODO validate p6sgi.xxx

    if %env<HTTP_CONTENT_TYPE> {
        die 'HTTP_CONTENT_TYPE should not exist';
    }
    if %env<HTTP_CONTENT_LENGTH> {
        die 'HTTP_CONTENT_LENGTH should not exist';
    }
}

my sub validate-ret(@ret) {
    unless @ret == 3 {
        die 'Response needs to be 3 element array';
    }

    unless @ret[0] ~~ /^\d+$/ && @ret[0] >= 100 {
        die "Status code needs to be an integer greater than or equal to 100: @ret[0]";
    }

    unless @ret[1].isa(List) {
        die "Headers needs to be an list: @ret[1]";
    }

    my $copy = @ret[1];

    {
        $copy.pairup();
        CATCH {
            default {
                die 'The number of response headers needs to be even, not odd(', $copy, ')';
            }
        }
    }

    for $copy.kv -> $i, $v {
        my ($key, $val) = $v.kv;

        if $key.lc eq 'status' {
            die 'Response headers MUST NOT contain a key named Status';
        }
        if $key ~~ /[<[: \r \n]> | <[- _]>]$/ {
            die "Response headers MUST NOT contain a key with : or newlines, or that end in - or _: $key";
        }
        unless $key ~~ /^<[a..z A..Z]><[0..9 a..z A..Z \- _]>*$/ {
            die "Response headers MUST consist only of letters, digits, _ or - and MUST start with a letter: $key";
        }

        unless $val.defined {
            die 'Response headers MUST be a defined string';
        }

        if $val ~~ /<[\o00..\o37]>/ {
            die "Response headers MUST NOT contain characters below octal \o37: $val";
        }
    }

    my $res-body = @ret[2];
    unless $res-body.isa(List) || $res-body.isa(Supply) || $res-body.isa(Channel) || $res-body.isa(IO::Handle) {
        die 'Body is not suitable type: ' ~ $res-body.WHAT.perl;
    }

    return @ret;
}

method CALL-ME(%env) {
    validate-env(%env);
    my @ret = $.app()(%env);
    return validate-ret(@ret);
}

=begin pod

=head1 NAME

Crust::Middleware::Lint - Validate request and response

=head1 SYNOPSIS

  use Crust::Middleware::Lint;

  my $app = sub { ... }; # your app
  $app = Crust::Middleware::Lint.new($app);

Or from crustup

  crustup --lint myapp.p6sgi

Or use with builder

  enable 'Lint';

=head1 DESCRIPTION

Crust::Middleware::Lint is a middleware component to validate request
and response environment formats. You are strongly suggested to use
this middleware when you develop a new framework adapter or a new P6SGI
web server that implements the P6SGI interface.

This middleware is inspired by L<Plack::Middleware::Lint|https://metacpan.org/pod/Plack::Middleware::Lint> and most of code is taken from that.

=head1 AUTHOR

moznion <moznion@gmail.com>

=end pod

