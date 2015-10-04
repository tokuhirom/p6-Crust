use v6;

unit class Crust::Request;

use URI::Escape;
use Hash::MultiValue;
use HTTP::MultiPartParser;
use Crust::Headers;
use Crust::Utils;
use Crust::Request::Upload;
use File::Temp; # tempfile
use Cookie::Baker;

has Hash $.env;
has Crust::Headers $headers;

method new(Hash $env) {
    self.bless(env => $env);
}

method address()      { $.env<REMOTE_ADDR> }
method remote-host()  { $.env<REMOTE_HOST> }
method protocol()     { $.env<SERVER_PROTOCOL> }
method method()       { $.env<REQUEST_METHOD> }
method port()         { $.env<SERVER_PORT> }
method user()         { $.env<REMOTE_USER> }
method request-uri()  { $.env<REQUEST_URI> }
method path-info()    { $.env<PATH_INFO> }
method path()         { $.env<PATH_INFO> || '/' }
method query-string() { $.env<QUERY_STRING> }
method script-name()  { $.env<SCRIPT_NAME> }
method scheme()       { $.env<psgi.url_scheme> }
method secure()       { $.scheme eq 'https' }
method body()         { $.env<psgi.input> }
method input()        { $.env<psgi.input> }

method content-length()   { $.env<CONTENT_LENGTH> }
method content-type()     { $.env<CONTENT_TYPE> }

method session()         { $.env<psgix.session> }
method session-options() { $.env<psgix.session.options> }
method logger()          { $.env<psgix.logger> }

method query-parameters() {
    my Str $query_string = $.env<QUERY_STRING>;
    my @pairs = $query_string.defined
        ?? parse-uri-query($query_string)
        !! ();
    return Hash::MultiValue.from-pairs(|@pairs);
}

my sub parse-uri-query(Str $query_string is copy) {
    $query_string = $query_string.subst(/^<[&;]>+/, '');
    my @pairs;
    for $query_string.split(/<[&;]>+/) {
        if $_ ~~ /\=/ {
            my ($k, $v) = @($_.split(/\=/, 2));
            @pairs.push(uri_unescape($k) => uri_unescape($v));
        } else {
            @pairs.push($_ => '');
        }
    }
    return @pairs;
}

method headers() {
    unless $!headers.defined {
        $!env.keys ==> grep {
            m:i/^(HTTP|CONTENT)/
        } ==> map {
            my $field = $_.subst(/^HTTPS?_/, '').subst(/_/, '-', :g);
            $field => $!env{$_}
        } ==> my %src;
        $!headers = Crust::Headers.new(%src);
    }
    return $!headers;
}

method header(Str $name) {
    $!headers.header($name);
}

method content() {
    # TODO: we should support buffering in Crust layer
    my $input = $!env<psgi.input>;
    $input.seek(0,0); # rewind
    my Blob $content = $input.slurp-rest(:bin);
    return $content;
}

method user-agent() { self.headers.user-agent }

method content-encoding() { self.headers.content-encoding }

method referer() { self.headers.referer }

method body-parameters() {
    $!env<crust.request.body> //= do {
        if self.content-type {
            my ($type, %opts) = parse-header-item(self.content-type);
            given $type {
                when 'application/x-www-form-urlencoded' {
                    my @q = parse-uri-query(self.content.decode('ascii'));
                    Hash::MultiValue.from-pairs(@q);
                }
                when 'multipart/form-data' {
                    my ($params, $uploads) = self!parse-multipart-parser(%opts<boundary>.encode('ascii'));
                    $!env<crust.request.upload> = $uploads;
                    $params;
                }
                default {
                    Hash::MultiValue.new
                }
            }
        } else {
            Hash::MultiValue.new
        }
    }
}

method uploads() {
    unless $!env<crust.request.upload>:exists {
        self.body-parameters();
        $!env<crust.request.upload> //= Hash::MultiValue.new;
    }
    return $!env<crust.request.upload>;
}

method !parse-multipart-parser(Blob $boundary) {
    my $headers;
    my Blob $content = Buf.new;
    my @parameters;
    my ($first, %opts);
    my @uploads;
    my ($tempfilepath, $tempfilefh);
    my $parser = HTTP::MultiPartParser.new(
        boundary => $boundary,
        on_header => sub ($h) {
            @$h ==> map {
                parse-header-line($_)
            } ==> my @pairs;
            $headers = Hash::MultiValue.from-pairs: |@pairs;
            my ($cd) = $headers<content-disposition>;
            die "missing content-disposition header in multipart" unless $cd;
            ($first, %opts) = parse-header-item($cd);
            if %opts<filename>:exists {
                ($tempfilepath, $tempfilefh) = tempfile();
            }
        },
        on_body => sub (Blob $chunk, Bool $final) {
            if %opts<filename>:exists {
                $tempfilefh.write($chunk);
            } else {
                $content ~= $chunk;
            }

            if $final {
                if %opts<filename>:exists {
                    my $filename = %opts<filename>;

                    @uploads.push(
                        %opts<name> => Crust::Request::Upload.new(
                            filename => %opts<filename>,
                            headers  => $headers,
                            path     => $tempfilepath.IO,
                        )
                    );
                } else {
                    @parameters.push(%opts<name> => $content.subbuf(0));
                }
                $content = Buf.new;
                undefine $headers;
            }
        },
        on_error => sub (Str $err) {
            # TODO: throw Bad Request
            die "Error while parsing multipart(boundary:{$boundary.decode('ascii')}):$err";
        },
    );
    $parser.parse(self.content);
    $parser.finish();
    my $params = Hash::MultiValue.from-pairs: @parameters;
    return $params, Hash::MultiValue.from-pairs(@uploads);
}

method parameters() {
    $!env<crust.request.merged> //= do {
        my Hash::MultiValue $q = self.query-parameters();
        my Hash::MultiValue $b = self.body-parameters();

        my @pairs = |$q.all-pairs;
        @pairs.push(|$b.all-pairs);
        Hash::MultiValue.from-pairs(|@pairs);
    };
}

method base() {
    self!uri-base;
}

method uri() {
    my $base = self!uri-base;

    # We have to escape back PATH_INFO in case they include stuff like
    # ? or # so that the URI parser won't be tricked. However we should
    # preserve '/' since encoding them into %2f doesn't make sense.
    # This means when a request like /foo%2fbar comes in, we recognize
    # it as /foo/bar which is not ideal, but that's how the PSGI PATH_INFO
    # spec goes and we can't do anything about it. See PSGI::FAQ for details.

    # See RFC 3986 before modifying.
    my $path_escape_class = rx!(<[^/;:@&= A..Z a..z 0..9 \$_.+!*'(),-]>)!;

    my $path = ($.env<PATH_INFO>// '').subst(
        $path_escape_class, -> $/ { $/[0].Str.ord.fmt('%%%02X') }
    );
    if $.env<QUERY_STRING>.defined && $.env<QUERY_STRING> ne '' {
        $path ~= '?' ~ $.env<QUERY_STRING>
    }

    if $path ~~ m/^\// {
        $base .= subst(/\/$/, '');
    }

    return $base ~ $path;
}

method !uri-base() {
    return ($!env<psgi.url_scheme> || "http") ~
        "://" ~
        ($!env<HTTP_HOST> || (($!env<SERVER_NAME> || "") ~ ":" ~ ($!env<SERVER_PORT> || 80))) ~
        ($!env<SCRIPT_NAME> || '/');
}

method cookies() {
    return {} unless $!env<HTTP_COOKIE>;

    if $!env<crust.cookie.parsed> && $!env<crust.cookie.string> eq $!env<HTTP_COOKIE> {
        return $!env<crust.cookie.parsed>;
    }

    my $parsed = crush-cookie($!env<HTTP_COOKIE>);
    $!env<crust.cookie.parsed> = $parsed;
    $!env<crust.cookie.string> = $!env<HTTP_COOKIE>;
}

# TODO: sub uri {
# TODO: sub new_response {

