use v6;

unit class Crust::Middleware::ReverseProxy does Callable;

has $.app;

method CALL-ME(%env) {
    # in apache2 httpd.conf (RequestHeader set X-Forwarded-HTTPS %{HTTPS}s)
    if %env<HTTP_X_FORWARDED_HTTPS> {
        %env<HTTPS> = %env<HTTP_X_FORWARDED_HTTPS>;
    }
    if %env<HTTP_X_FORWARDED_PROTO> && %env<HTTP_X_FORWARDED_PROTO> eq 'https' {
        %env<HTTPS> = 'ON';
    }
    if (%env<HTTPS> && %env<HTTPS>.uc eq 'ON') || (%env<HTTP_HTTPS> && %env<HTTP_HTTPS>.uc eq 'ON') {
        %env<p6sgi.url_scheme> = 'https';
    }
    my $default_port = %env<p6sgi.url_scheme> eq 'https' ?? 443 !! 80;

    # If we are running as a backend server, the user will always appear
    # as 127.0.0.1. Select the most recent upstream IP (last in the list)
    if %env<HTTP_X_FORWARDED_FOR> {
        my ($ip) = %env<HTTP_X_FORWARDED_FOR> ~~ /(<-[, \s]>+)$/;
        %env<REMOTE_ADDR> = $ip;
    }

    if %env<HTTP_X_FORWARDED_HOST> {
        # in apache1 ServerName example.com:443
        if %env<HTTP_X_FORWARDED_SERVER> {
            my ($host) = %env<HTTP_X_FORWARDED_SERVER> ~~ /(<-[, \s]>+)$/;
            if $host ~~ /^.+ ':' (\d+)$/ {
                %env<SERVER_PORT> = $0;
                if %env<SERVER_PORT> == 443 {
                    %env<p6sgi.url_scheme>  = 'https';
                }
            }
            %env<HTTP_HOST> = $host;
        }

        my ($host) = %env<HTTP_X_FORWARDED_HOST> ~~ /(<-[, \s]>+)$/;
        if $host ~~ /^.+ ':' (\d+)$/ {
            %env<SERVER_PORT> = $0;
        } elsif %env<HTTP_X_FORWARDED_PORT> {
            # in apache2 httpd.conf (RequestHeader set X-Forwarded-Port 8443)
            %env<SERVER_PORT> = %env<HTTP_X_FORWARDED_PORT>;
            $host ~= ":%env<SERVER_PORT>";
            if %env<SERVER_PORT> == 443 {
                %env<p6sgi.url_scheme> = 'https';
            }
        } else {
            %env<SERVER_PORT> = $default_port;
        }
        %env<HTTP_HOST> = $host;
    } elsif %env<HTTP_HOST> {
        my $host = %env<HTTP_HOST>;
        if $host ~~ /^.+ ':' (\d+)$/ {
            %env<SERVER_PORT> = $0;
        } elsif $host ~~ /^(.+)$/ {
            %env<HTTP_HOST>   = $0;
            %env<SERVER_PORT> = $default_port;
        }
    }

    return $.app()(%env);
}

=begin pod

=head1 NAME

Crust::Middleware::ReverseProxy - Supports app to run as a reverse proxy backend

=head1 SYNOPSIS

  use Crust::Middleware::ReverseProxy;

  my $app = sub { ... }; # your app
  $app = ::('Crust::Middleware::ReverseProxy').new(app => $app);

=head1 DESCRIPTION

Crust::Middleware::ReverseProxy resets some HTTP headers, which changed by reverse-proxy.

This middleware is perl6 port of L<Plack::Middleware::ReverseProxy|https://metacpan.org/pod/Plack::Middleware::ReverseProxy>.

=head1 AUTHOR

moznion <moznion@gmail.com>

=head1 ORIGINAL AUTHORS

This module is originally written by Kazuhiro Osawa as L<HTTP::Engine::Middleware::ReverseProxy of perl5|https://metacpan.org/pod/HTTP::Engine::Middleware::ReverseProxy> for L<HTTP::Engine of perl5|https://metacpan.org/pod/HTTP::Engine>.

Nobuo Danjou

Masahiro Nagano

Tatsuhiko Miyagawa

=head1 SEE ALSO

=item L<Plack::Middleware::ReverseProxy|https://metacpan.org/pod/Plack::Middleware::ReverseProxy>

=end pod

