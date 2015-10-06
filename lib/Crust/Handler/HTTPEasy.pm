use v6;

unit class Crust::Handler::HTTPEasy;

use HTTP::Easy::PSGI;

has $.host;
has $.port;

method new(*%args) {
    my $host = %args<host> // '127.0.0.1';
    my $port = %args<port> // 0;
    self.bless(host => $host, port => $port);
}

method run(Callable $app) {
    my $http = HTTP::Easy::PSGI.new(:port($.port), :host($.host));
    $http.handle($app);
}

