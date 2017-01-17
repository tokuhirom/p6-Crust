use v6;
unit class Crust::Test;

our $Impl;
$Impl ||= %*ENV<CRUST_TEST_IMPL> || "MockHTTP";

# This is not required. But perl6.beta@20151013 is broken.
# perl6-m dumps core without following line.
# This is workaround for the issue. We should remove following line before christmas.
use Crust::Test::MockHTTP;

use MONKEY-SEE-NO-EVAL;

method create(Crust::Test:U: Callable $app, *@args) {
    my $subclass = "Crust::Test::$Impl";

    # FIXME: workaround for Bug RT #130535
    # ref: https://github.com/tokuhirom/p6-Crust/pull/86
    EVAL "use $subclass";

    ::($subclass).new(:$app); # @args
}

multi test-psgi(Callable $app, Callable $client) is export {
    test-psgi(:$app, :$client);
}

multi test-psgi(Callable :$app!, Callable :$client!) is export {
    my $tester = Crust::Test.create($app);
    my $cb = -> $req { $tester.request($req) };
    $client($cb);
}

=begin pod

=head1 NAME

Crust::Test - Test PSGI applications

=head1 SYNOPSIS

  use Crust::Test;
  use HTTP::Request;

  # OO
  my $app = -> $env { 200,[],['hello'] };
  my $test = Crust::Test.create($app);
  my $req = HTTP::Request.new(GET => "/");
  my $res = $test.request($req);
  is $res.content, "hello".encode;

  # Functional, named parameters
  test-psgi
      app => $app,
      client => -> $cb {
          my $req = HTTP::Request.new(GET => "/");
          my $res = $cb($req);
          is $res->content, "hello".encode;
      },
  ;

  # Functional, potitional parameters
  test-psgi $app, -> $cb {
      my $req = HTTP::Request.new(GET => "/");
      my $res = $cb($req);
      is $res->content, "hello".encode;
  };

=head1 DESCRIPTION

Crust::Test is a port of perl5 Plack::Test.

Crust::Test is a unified interface to test PSGI applications using
L<HTTP::Request> and L<HTTP::Response> objects. It also allows you to run PSGI
applications in various ways. The default backend is C<Crust::Test::MockHTTP>,
but you may also use any L<Crust::Handler> implementation to run live HTTP
requests against a web server.

=head1 AUTHOR

Shoichi Kaji

=head1 ORIGINAL AUTHOR

This file is port of Plack's Plack::Test written by Tatsuhiko Miyagawa

=end pod
