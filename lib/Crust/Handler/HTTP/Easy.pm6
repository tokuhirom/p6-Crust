use v6;

unit class Crust::Handler::HTTP::Easy;

use HTTP::Easy::PSGI;

has $!http;

method new(*%args) {
    self.bless()!initialize(%args);
}

method !initialize(%args) {
    $!http = HTTP::Easy::PSGI.new(|%args);
    self;
}

method run(Crust::Handler::HTTP::Easy:D: Callable $app) {
    $!http.handle($app);
}

=begin pod

=head1 NAME

Crust::Handler::HTTP::Easy - Crust adapter for HTTP::Easy::PSGI

=head1 SYNOPSIS

    crustup -s HTTP::Easy app.p6sgi

=end pod
