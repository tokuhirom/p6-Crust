use v6;

unit class Crust::App::URLMap does Callable;

has Array $!mapping;

multi method map(Str $location, Callable $callable) {
    my $loc = $location;
    my Str $host;
    if $loc ~~ /^ 'http' 's'? '://' (.*?) ('/' .*)/ {
        $host = $0.Str || '';
        $loc  = $1.Str || '';
    } 
    $loc = $loc.subst(/\/+ $/, '');
    $!mapping.push: {host => $host, loc => $loc, app => $callable};
    return self;
}

method CALL-ME($env) {
    self.call($env);
}

method call(Hash $env) {
    my $path_info   = $env<PATH_INFO>;
    my $script_name = $env<SCRIPT_NAME>;

    my $http_host = $env<HTTP_HOST>;
    my $server_name = $env<SERVER_NAME>;

    for $!mapping.keys -> $i {
        my $map = $!mapping[$i];
        my $path = $path_info; # copy
        next unless not defined $map<host> or
                    $http_host   eq $map<host> or
                    $server_name eq $map<host>;
        my $loc = $map<loc>;
        next if $loc  ne '' and $path !~~ s/^ $loc //;
        next if $path ne '' and $path !~~ /^ '/'/;

        my $orig_path_info   = $env<PATH_INFO>;
        my $orig_script_name = $env<SCRIPT_NAME>;

        $env<PATH_INFO>  = $path;
        $env<SCRIPT_NAME> = $script_name ~~ $loc;
        my @res = $map<app>($env);
        $env<PATH_INFO> = $orig_path_info;
        $env<SCRIPT_NAME> = $orig_script_name;
        return @res;
    }

    return 404, ['Content-Type' => 'text/plain'], ["Not Found"];
}

method to-app() {
    sub ($env) { self.call($env) }
}

=begin pod

=head1 NAME

Crust::Middleware::URLMap - Map multiple apps in different paths

=head1 SYNOPSIS

  use Crust::Middleware::URLMap;

  my $urlmap = sub { ... }; # your app
  $urlmap = ::('Crust::Middleware::URLMap').new($app);
  $urlmap.map "/", sub { ... };
  $urlmap.to-app;

=head1 DESCRIPTION

Crust::Middleware::URLMap privides URL map.

This middleware is perl6 port of L<Plack::Middleware::URLMap|https://metacpan.org/pod/Plack::Middleware::URLMap>.

=head1 AUTHOR

mattn <mattn.jp@gmail.com>

=head1 SEE ALSO

=item L<Plack::Middleware::URLMap|https://metacpan.org/pod/Plack::Middleware::URLMap>

=end pod
