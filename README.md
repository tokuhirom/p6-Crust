[![Build Status](https://travis-ci.org/tokuhirom/p6-Crust.svg?branch=master)](https://travis-ci.org/tokuhirom/p6-Crust)

NAME
====

Crust - Perl6 Superglue for Web frameworks and Web Servers

DESCRIPTION
===========

Crust is a set of tools for using the PSGI stack. It contains
middleware components(TBI), and utilities for Web application
frameworks. Crust is like Perl5's Plack, Ruby's Rack, Python's Paste
for WSGI.

See [PSGI](PSGI) for the PSGI specification.

MODULES AND UTILITIES
=====================

Crust::Handler
--------------

Crust::Handler and its subclasses contains adapters for web
servers. We have adapters for the built-in standalone web server
HTTP::Easy::PSGI, and HTTP::Server::Tiny included in the core Crust
distribution.

See [Crust::Handler](Crust::Handler) when writing your own adapters.

Crust::Middleware
-----------------

P6SGI middleware is a P6SGI application that wraps an existing P6SGI
application and plays both side of application and servers. From the
servers the wrapped code reference still looks like and behaves
exactly the same as P6SGI applications.

Crust::Request, Crust::Response
-------------------------------

Crust::Request gives you a nice wrapper API around PSGI $env hash to
get headers, cookies and query parameters much like Apache::Request in
mod_perl.

Crust::Response does the same to construct the response array
reference.

.p6sgi files
------------

A PSGI application is a code reference but it's not easy to pass code
reference via the command line or configuration files, so Crust uses a
convention that you need a file named "app.p6sgi" or similar, which
would be loaded (via perl6's core function "EVALFILE") to return the
PSGI application code reference.

    # Hello.p6sgi
    my $app = sub ($env) {
        # ...
        return $status, $headers, $body;
    };

If you use a web framework, chances are that they provide a helper
utility to automatically generate these ".p6sgi" files for you, such
as:

    # MyApp.p6sgi
    use MyApp;
    my $app = sub { MyApp->run_psgi(@_) };

It's important that the return value of ".p6sgi" file is the code
reference. See "eg/" directory for more examples of ".p6sgi" files.

An Alternative to .p6sgi files
------------------------------

As an alternative to using EVAL, you can take advantage of Perl's
Callable type which will return a code reference as well, making Crust
happy.

Here is an example of an implmentation using a Callable class in place
of any .p6sgi files and having to call a "crustup" script. You can
call this directly from the command line, just like you would
"crustup".

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

AUTHORS
=======

  * Tokuhiro Matsuno

  * mattn

  * Shoichi Kaji

  * Daisuke Maki

  * moznion

  * Kentaro Kuribayashi

  * Tim Smith

  * fayland

COPYRIGHT AND LICENSE
=====================

Copyright 2015 Tokuhiro Matsuno <tokuhirom@gmail.com>

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.
