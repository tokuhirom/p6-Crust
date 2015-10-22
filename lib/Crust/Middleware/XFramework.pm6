use v6;
use Crust::Middleware;

unit class Crust::Middleware::XFramework is Crust::Middleware;

has $.framework;

method CALL-ME(%env) {
    my @ret = $.app()(%env);

    if $.framework {
        my %headers = %(@ret[1]);
        %headers<X-Framework> = $.framework;
        @ret[1] = [%headers];
    }

    return @ret;
}

=begin pod

=head1 NAME

Crust::Middleware::XFramework - Sets an X-Framework response header

=head1 SYNOPSIS

    use Crust::Middleware::XFramework;

    my $app = sub { ... }; # your app
    $app = Crust::Middleware::XFramework.new($app, :framework<YOUR-AWESOME-FRAMEWORK>);

Or use with builder

    enable 'XFramework', :framework<YOUR-AWESOME-FRAMEWORK>;

=head1 DESCRIPTION

Crust::Middleware::XFramework is a middleware component that sets the name of
the Web application framework on which your application runs response in the
I<X-Framework> HTTP response header.

This middleware is inspired by L<Plack::Middleware::XFramework|https://metacpan.org/pod/Plack::Middleware::XFramework>.

=head1 AUTHOR

Kentaro Kuribayashi <kentarok@gmail.com>

=end pod
