use v6;

unit class Crust::Handler::HTTP::Server::Tiny;

use HTTP::Server::Tiny;

has %.args;

method new(*%args) {
    self.bless(args => %args);
}

method run(Crust::Handler::HTTP::Server::Tiny:D: Callable $app) {
    my $httpd = HTTP::Server::Tiny.new(|%!args);
    $httpd.run($app);
}

=begin pod

=head1 NAME

Crust::Handler::HTTP::Server::Tiny - Crust adapter for HTTP::Server::Tiny

=head1 SYNOPSIS

    crustup -s HTTP::Server::Tiny app.p6sgi

=end pod
