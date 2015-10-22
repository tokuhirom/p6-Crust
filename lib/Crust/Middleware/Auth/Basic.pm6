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

    if ! self!authenticate($user, $pass, %env) {
        return self.unauthorized()
    }

    %env<REMOTE_USER> = $user;
    return $.app.(%env);
}

=begin pod

=head1 NAME

Crust::Middleware::Auth::Basic - Simple basic authentication middleware

=head1 SYNOPSIS

    use Crust::Builder;
    my $app = sub { ... };

    my sub authen_cb($username, $password, %env) {
        return $username eq 'admin' && $password eq 's3cr3t';
    }

    builder {
        enable "Auth::Basic", :authenticator(\&authen_cb);
        $app;
    };

=head1 DESCRIPTION

Crust::Middleware::Auth::Basic is a basic authentication handler for Crust.

=head1 CONFIGURATION

=item authenticator :Callable | :Object

    :authenticator(-> $user, $pass, %env { ... });

A callback function that takes username, password and PSGI environment
supplied and returns whether the authentication succeeds. Required.

Authenticator can also be an object that responds to C<authenticate>
method that takes username and password and returns boolean.

=item realm :Str

Realm name to display in the basic authentication dialog. Defaults to I<restricted area>.

=head1 LIMITATIONS

This middleware expects that the application has a full access to the
headers sent by clients in PSGI environment. That is normally the case
with standalone P6SGI web servers .

However, in a web server configuration where you can't achieve this
(i.e. using your application via Apache's mod_cgi), this middleware
does not work since your application can't know the value of
C<Authorization:> header.

If you use Apache as a web server and CGI to run your PSGI
application, you can either a) compile Apache with
C<-DSECURITY_HOLE_PASS_AUTHORIZATION> option, or b) use mod_rewrite to
pass the Authorization header to the application with the rewrite rule
like following.

    RewriteEngine on
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization},L]

=head1 AUTHOR

Daisuke Maki

=head1 SEE ALSO

L<Crust>

=end pod
