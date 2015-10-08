use v6;

unit class Crust::Middleware::Lint does Callable;

has $.app;

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
    if (%env<PATH_INFO> ne '' && %env<PATH_INFO> !~~ m!^'/'!) {
        die "PATH_INFO must begin with / (%env<PATH_INFO>)";
    }
    unless (%env<SERVER_NAME>.defined) {
        die 'Missing mandatory env param: SERVER_NAME';
    }
    if (%env<SERVER_NAME> eq '') {
        die 'SERVER_NAME must not be empty string';
    }
    unless (%env<SERVER_PORT>.defined) {
        die 'Missing mandatory env param: SERVER_PORT';
    }
    if (%env<SERVER_PORT> eq '') {
        die 'SERVER_PORT must not be empty string';
    }
    if (%env<SERVER_PROTOCOL>.defined && %env<SERVER_PROTOCOL> !~~ m{^HTTP'/'\d}) {
        die "Invalid SERVER_PROTOCOL: $env->{SERVER_PROTOCOL}";
    }

    # TODO validate p6sgi.xxx

    if (%env<HTTP_CONTENT_TYPE>) {
        die 'HTTP_CONTENT_TYPE should not exist';
    }
    if (%env<HTTP_CONTENT_LENGTH>) {
        die 'HTTP_CONTENT_LENGTH should not exist';
    }
}

my sub validate-ret(@ret) {
    unless @ret == 3 {
        die 'Response needs to be 3 element array';
    }

    unless (@ret[0] ~~ /^\d+$/ && @ret[0] >= 100) {
        die "Status code needs to be an integer greater than or equal to 100: @ret[0]";
    }

    unless (@ret[1].isa(Array)) {
        die "Headers needs to be an array: @ret[1]";
    }

    my @copy = @ret[1];

    {
        @copy.pairup();
        CATCH {
            default {
                die 'The number of response headers needs to be even, not odd(', @copy, ')';
            }
        }
    }


    for @copy.kv -> $i, $v {
        next if $v.defined;
        my ($key, $val) = @copy[$i].kv;

        if $key.lc eq 'status' {
            die 'Response headers MUST NOT contain a key named Status';
        }
        if $key ~~ /[<[: \r \n]> | <[- _]>]$/ {
            die "Response headers MUST NOT contain a key with : or newlines, or that end in - or _: $key";
        }
        unless $key ~~ /^<[a..z A..Z]><[0..9 a..z A..Z - _]>*$/ {
            die "Response headers MUST consist only of letters, digits, _ or - and MUST start with a letter: $key";
        }
        if ($val =~ /<[\o00..\o37]>/) {
            die("Response headers MUST NOT contain characters below octal \o37: $val");
        }
        unless $val.defined {
            die 'Response headers MUST be a defined string';
        }
    }

    unless @ret[2].isa(Array) { # TODO filehandle
        die "Body should be an array ref or filehandle: @res[2]";
    }

    return $res;
}

method CALL-ME(%env) {
    validate-env(%env);
    my @ret = $.app()(%env);
    return validate-ret(@ret);
}

