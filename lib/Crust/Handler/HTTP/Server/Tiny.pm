use v6;

unit class Crust::Handler::HTTP::Server::Tiny;

use HTTP::Server::Tiny;

has Str $.host;
has int $.port;

method new(*%args) {
    my Str $host = %args<host> // '127.0.0.1';
    my int $port = %args<port> // 5000;
    self.bless(host => $host, port => $port);
}

method run(Crust::Handler::HTTP::Server::Tiny:D: Callable $app) {
    my $httpd = HTTP::Server::Tiny.new(host => $.host, port => $.port);
    $httpd.run($app);
}

=begin pod

=head1 NAME

Crust::Handler::HTTP::Server::Tiny - Crust adapter for HTTP::Server::Tiny

=head1 SYNOPSIS

    crustup -s HTTP::Server::Tiny app.psgi

=end pod
