use v6;
use Base64;
use Crust::Middleware;
use Crust::Utils;

unit class Crust::Middleware::Auth::Basic is Crust::Middleware;

has $.realm;
has $.authenticator;

method unauthorized () {
    my $authenticate = q!Basic realm="! ~ ($.realm || "restricted area") ~ q!"!;
    my $body = 'Authorization required';

    return
        401,
        [:Content-Type("text/plain"),
         :Content-Length(content-length($body)),
         :WWW-Authenticate($authenticate)],
        [$body]
    ;
}

method !authenticate($user, $pass, %env) {
    my $a = $.authenticator;
    given $a {
        when Callable { return $a.($user, $pass, %env) }
        when .can("authenticate") { return $a.authenticate($user, $pass, %env) }
    }

    return False;
}

# TODO: make the error visible to the caller?
my sub decode-token($token) {
    # ignore them errors
    CATCH { default { return } };
    return (decode-base64($token, :buf).decode() || ":").split(/':'/, 2);
}

method CALL-ME(%env) {
    my $hdr = %env<HTTP_AUTHORIZATION>;
    if ! $hdr {
        return self.unauthorized()
    }

    if $hdr !~~ /:i ^ 'Basic' \s+ (\S+) \s* $/ {
        return self.unauthorized()
    }

    my ($user, $pass) = decode-token($0.Str);
    if !$user {
        return self.unauthorized();
    }

    if ! $pass.defined {
        $pass = '';
    }

    if self!authenticate($user, $pass, %env) {
        %env<REMOTE_USER> = $user;
        return $.app.(%env);
    }
    return self.unauthorized()
}