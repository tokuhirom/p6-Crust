use v6;
unit class Crust;


=begin pod

=head1 NAME

Crust - Perl6 Superglue for Web frameworks and Web Servers

=head1 DESCRIPTION

Crust is a set of tools for using the P6W stack. It contains middleware
components, and utilities for Web application frameworks.
Crust is like Perl5's Plack, Ruby's Rack, Python's Paste for WSGI.

See L<P6W|https://github.com/zostay/P6W> for the P6W (former known as P6SGI) specification.

=head1 MODULES AND UTILITIES

=head2 Crust::Handler

Crust::Handler and its subclasses contains adapters for web servers. We
have adapters for the built-in standalone web server HTTP::Easy::PSGI,
and HTTP::Server::Tiny included in the core Crust distribution.

See L<Crust::Handler> when writing your own adapters.

=head2 Crust::Middleware

P6W middleware is a P6W application that wraps an existing P6W
application and plays both side of application and servers. From the
servers the wrapped code reference still looks like and behaves exactly
the same as P6W applications.

=head2 Crust::Request, Crust::Response

Crust::Request gives you a nice wrapper API around P6W $env hash to get
headers, cookies and query parameters much like Apache::Request in
mod_perl.

Crust::Response does the same to construct the response array reference.

=head2 .p6w files

A P6W application is a code reference but it's not easy to pass code
reference via the command line or configuration files, so Crust uses a
convention that you need a file named "app.p6w" or similar, which would
be loaded (via perl6's core function "EVALFILE") to return the P6W application
code reference.

    # Hello.p6w
    my $app = sub ($env) {
        # ...
        return $status, $headers, $body;
    };

If you use a web framework, chances are that they provide a helper utility
to automatically generate these ".p6w" files for you, such as:

    # MyApp.p6w
    use MyApp;
    my $app = sub { MyApp->run_p6w(@_) };

It's important that the return value of ".p6w" file is the code
reference. See "eg/" directory for more examples of ".p6w" files.

=head1 An Alternative to .p6w files

As an alternative to using EVAL, you can take advantage of Perl's Callable type which will return a code reference as well, making Crust happy.

Here is an example of an implmentation using a Callable class in place of any .p6w files and having to call a "crustup" script. You can call this directly from the command line, just like you would "crustup".

    use v6;
    
    use Crust::Runner;
    
    class MyApp does Callable
    {
        has $.status  is rw;
        has @.headers is rw;
        has @.body    is rw;
    
        method CALL-ME(%env) {
            self.call(%env);
        }
    
        method call(%env) {
    
            $.status  = 200;
            @.headers = [ 'Content-Type' => 'text/html' ];
            @.body    = [ '<html><head><title>Hi</title></head>',
                          '<body>I just want you to see me</body>',
                          '</html>',
                        ];
    
            return $.status, @.headers, @.body;
        }
    }
    
    my $runner = Crust::Runner.new;
    $runner.parse-options(@*ARGS);
    $runner.run(MyApp.new);

=head1 AUTHORS

=item Tokuhiro Matsuno

=item mattn

=item Shoichi Kaji

=item Daisuke Maki

=item moznion

=item Kentaro Kuribayashi

=item Tim Smith

=item fayland

=head1 COPYRIGHT AND LICENSE

Copyright 2015 Tokuhiro Matsuno <tokuhirom@gmail.com>

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
