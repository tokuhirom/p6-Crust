[![Build Status](https://travis-ci.org/tokuhirom/p6-Crust.svg?branch=master)](https://travis-ci.org/tokuhirom/p6-Crust)

NAME
====

Crust - Perl6 Superglue for Web frameworks and Web Servers

DESCRIPTION
===========

Crust is a set of tools for using the PSGI stack. It contains middleware components(TBI), and utilities for Web application frameworks. Crust is like Perl5's Plack, Ruby's Rack, Python's Paste for WSGI.

See [PSGI](PSGI) for the PSGI specification.

MODULES AND UTILITIES
=====================

Crust::Handler
--------------

TODO

Crust::Middleware
-----------------

TODO

.psgi6 files
------------

A PSGI application is a code reference but it's not easy to pass code reference via the command line or configuration files, so Crust uses a convention that you need a file named "app.psgi6" or similar, which would be loaded (via perl6's core function "EVALFILE") to return the PSGI application code reference.

    # Hello.psgi6
    my $app = sub ($env) {
        # ...
        return $status, $headers, $body;
    };

If you use a web framework, chances are that they provide a helper utility to automatically generate these ".psgi" files for you, such as:

    # MyApp.psgi6
    use MyApp;
    my $app = sub { MyApp.run_psgi(@_) };

It's important that the return value of ".psgi" file is the code reference. See "eg/" directory for more examples of ".psgi" files.

AUTHORS
=======

  * Tokuhiro Matsuno

  * mattn

COPYRIGHT AND LICENSE
=====================

Copyright 2015 Tokuhiro Matsuno <tokuhirom@gmail.com>

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.
