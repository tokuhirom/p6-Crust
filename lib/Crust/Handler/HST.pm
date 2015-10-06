use v6;

unit class Crust::Handler::HST;

use HTTP::Server::Tiny;

has Str $.host;
has int $.port;

method new(*%args) {
    my Str $host = %args<host> // '127.0.0.1';
    my int $port = %args<port> // 5000;
    self.bless(host => $host, port => $port);
}

method run(Crust::Handler::HST:D: Callable $app) {
    my $httpd = HTTP::Server::Tiny.new(host => $.host, port => $.port);
    $httpd.run($app);
}

=begin pod

=head1 NAME

Crust::Handler::HST - Crust adapter for HTTP::Server::Tiny

=head1 SYNOPSIS

    crustup -s HST app.psgi

=end pod
