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
method scheme()       { $.env<p6sgi.url-scheme> }
method secure()       { $.scheme eq 'https' }
method body()         { $.env<p6sgi.input> }
method input()        { $.env<p6sgi.input> }

method content-length()   { $.env<CONTENT_LENGTH> }
method content-type()     { $.env<CONTENT_TYPE> }

method session()         { $.env<p6sgix.session> }
method session-options() { $.env<p6sgix.session.options> }
method logger()          { $.env<p6sgix.logger> }

# TODO cache
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
    my $input = $!env<p6sgi.input>;
    $input.seek(0, SeekFromBeginning); # rewind
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
    my $path_escape_class = rx!(<-[/;:@&= A..Z a..z 0..9 \$_.+!*'(),-]>)!;

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
    return ($!env<p6sgi.url-scheme> || "http") ~
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
    return $parsed;
}

=begin pod

=head1 NAME

Crust::Request - Request object

=head1 DESCRIPTION

PSGI request object

=head1 METHODS

=head2 C<method new(Hash $env)>

Create new instance of this class by P6SGI's env.

=head2 C<method address()      { $.env<REMOTE_ADDR> }>
=head2 C<method remote-host()  { $.env<REMOTE_HOST> }>
=head2 C<method protocol()     { $.env<SERVER_PROTOCOL> }>
=head2 C<method method()       { $.env<REQUEST_METHOD> }>
=head2 C<method port()         { $.env<SERVER_PORT> }>
=head2 C<method user()         { $.env<REMOTE_USER> }>
=head2 C<method request-uri()  { $.env<REQUEST_URI> }>
=head2 C<method path-info()    { $.env<PATH_INFO> }>
=head2 C<method path()         { $.env<PATH_INFO> || '/' }>
=head2 C<method query-string() { $.env<QUERY_STRING> }>
=head2 C<method script-name()  { $.env<SCRIPT_NAME> }>
=head2 C<method scheme()       { $.env<p6sgi.url-scheme> }>
=head2 C<method secure()       { $.scheme eq 'https' }>
=head2 C<method body()         { $.env<p6sgi.input> }>
=head2 C<method input()        { $.env<p6sgi.input> }>
=head2 C<method content-length()   { $.env<CONTENT_LENGTH> }>
=head2 C<method content-type()     { $.env<CONTENT_TYPE> }>
=head2 C<method session()         { $.env<p6sgix.session> }>
=head2 C<method session-options() { $.env<p6sgix.session.options> }>
=head2 C<method logger()          { $.env<p6sgix.logger> }>

Short-hand to access.

=head2 C<method query-parameters(:D:)>

Get parsing result of QUERY_STRING in L<Hash::MultiValue>.

=head2 C<method headers()>

Get a instance of L<Crust::Headers>.

=head2 C<method header(Str $name)>

Get header value by C<$name>.

=head2 C<method user-agent()>

Get C<User-Agent> header value.

=head2 C<method content-encoding()>

Get C<Content-Encoding> header value.

=head2 C<method referer()>

Get C<Referer> header value.

=head2 C<method body-parameters()>

Return parsing result of content-body.

Current implementation supports application/x-www-form-urlencoded and multipart/form-data.

Return value's type is Hash::MultiValue.

=head2 C<method uploads()>

Get uploaded file map in Hash::MultiValue. This hash's values are instance of L<Crust::Request::Upload>.

=head2 C<method parameters()>

Get merged result of C<body-parameters> and C<query-parameters>.

=head2 C<method base()>

Returns the base path of current request. This is
like "uri" but only contains up to "SCRIPT_NAME" where your
application is hosted at.

=head2 C<method uri()>

Returns the current request URI.

The URI is constructed
using various environment values such as "SCRIPT_NAME", "PATH_INFO",
"QUERY_STRING", "HTTP_HOST", "SERVER_NAME" and "SERVER_PORT"

=head2 C<method cookies()>

Get parsing result of cookies.

=head1 AUTHOR

Tokuhiro Matsuno

=head1 ORIGINAL AUTHOR

This file is port of Plack's.
Plack::Request is written by

=item Tatsuhiko Miyagawa

=item Kazuhiro Osawa

=item Tokuhiro Matsuno

=end pod
