use v6;
use Crust::Utils;
use Crust::App::URLMap;
use Crust::Middleware::Conditional;

unit class Crust::Builder;

has @!middlewares;
has $!url-map;

multi method add-middleware(Str $middleware, |opts) {
    my $middleware-class = load-class($middleware, 'Crust::Middleware');
    self.add-middleware(sub ($app) {
        ::($middleware-class).new($app, |opts);
    });
}

multi method add-middleware(Callable $middleware) {
    @!middlewares.push($middleware);
}

multi method add-middleware-if(Callable $condition, Str $middleware, *%args) {
    my $middleware-class = load-class($middleware, 'Crust::Middleware');
    self.add-middleware-if($condition, sub ($app) {
        ::($middleware-class).new($app, |%args);
    });
}

multi method add-middleware-if(Callable $condition, Callable $middleware) {
    @!middlewares.push(sub ($app) {
        Crust::Middleware::Conditional.new($app, :condition($condition), :builder($middleware));
    });
}

method mount(Str $location, Callable $app) {
    unless $!url-map.defined {
        $!url-map = Crust::App::URLMap.new;
    }

    $!url-map.map($location, $app);
}

method to-app(Callable $app) {
    if $app.defined {
        self.wrap($app)
    } elsif $!url-map.defined {
        $!url-map = $!url-map.to-app;
        self.wrap($!url-map);
    } else {
        die "to-app() is called without mount(). No application to build.";
    }
}

method wrap(Callable $app) returns Callable {
    if $!url-map.defined && $app !~~ $!url-map {
        die "WARNING: wrap() and mount() can't be used altogether in Crust::Builder.\n" ~
            "WARNING: This causes all previous mount() mappings to be ignored.";
    }

    my Callable $_app = $app;
    for @!middlewares.reverse -> $mw {
        $_app = $mw.($_app);
    }

    return $_app;
}

### DSL

my $_add = my $_add-if = my $_mount = sub (|) {
    die "enable/mount should be called inside builder {} block";
}

sub enable($middleware, |opts) is export {
	$_add.($middleware, |opts);
}

sub enable-if(Callable $condition, $middleware, |opts) is export {
    $_add-if.($condition, $middleware, |opts);
}

sub mount(Str $location, Callable $block) is export {
    $_mount.($location, $block);
}

sub builder(Callable $block) is export {
    my $builder = Crust::Builder.new;

    my $mount-is-called;
    my $url-map = Crust::App::URLMap.new;

    temp $_mount = sub (Str $location, Callable $block) {
        $mount-is-called++;
        $url-map.map($location, $block);
        return $url-map;
    };

    temp $_add = sub ($middleware, |opts) {
        $builder.add-middleware($middleware, |opts);
    };

    temp $_add-if = sub (Callable $condition, $middleware, |opts) {
        $builder.add-middleware-if($condition, $middleware, |opts);
    };

    my $app = $block.();

    if $mount-is-called {
        if $app !~~ $url-map {
            die "WARNING: You used mount() in a builder block, but the last line (app) isn't using mount().\n" ~
                "WARNING: This causes all mount() mappings to be ignored.\n";
        } else {
            $app = $app.to-app;
        }
    }

    $builder.to-app($app);
}

=begin pod

=head1 NAME

Crust::Builder - Utility to enable Crust middlewares

=head1 SYNOPSIS

    # in .p6sgi
    use Crust::Builder;

    my $app = sub { ... };

    builder {
        enable "AccessLog", format => "combined";
        enable "ContentLength";
        enable "+My::Crust::Middleware";
        $app;
    };

    # use URLMap
    builder {
        mount "/foo", builder {
            enable "Foo";
            $app;
        };

        mount "/bar", $app2;
        mount "http://example.com/", builder { $app3 };
    };

    # using OO interface
    my $builder = Crust::Builder.new;
    $builder.add-middleware('Foo', opt => 1);
    $builder.add-middleware('Bar');
    $builder.wrap($app);

=head1 DESCRIPTION

Crust::Builder gives you a quick domain specific language (DSL) to
wrap your application with Crust::Middleware.
This utility is inspired by L<Plack::Builder|https://metacpan.org/pod/Plack::Builder>.

Whenever you call C<enable> on any middleware, the middleware app is
pushed to the stack inside the builder, and then reversed when it
actually creates a wrapped application handler.
C<"Crust::Middleware::"> is added as a prefix by default. So:

    builder {
        enable "Foo";
        enable "Bar", opt => "val";
        $app;
    };

is syntactically equal to:

    $app = Crust::Middleware::Bar.new($app, opt => "val");
    $app = Crust::Middleware::Foo.new($app);

In other words, you're supposed to C<enable> middleware from outer to inner.

=head1 INLINE MIDDLEWARE

Crust::Builder allows you to code middleware inline using a nested
code reference.

If the first argument to C<enable> is a code reference, it will be
passed an C<$app> and should return another code reference
which is a P6SGI application that consumes C<%env> at runtime. So:

    builder {
        enable sub ($app) {
            return sub (%env) {
                # do preprocessing
                my @res = $app(%env);
                # do postprocessing
                return @res;
            };
        };
        $app;
    };

=head1 URLMap support

Crust::Builder has a native support for L<Crust::App::URLMap> via the C<mount> method.

    use Crust::Builder;
    my $app = builder {
        mount "/foo", $app1;
        mount "/bar", builder {
            enable "Foo";
            $app2;
        };
    };

See L<Crust::App::URLMap>'s C<map> method to see what they mean. With
C<builder> you can't use C<map> as a DSL, for the obvious reason :)

B<NOTE>: Once you use C<mount> in your builder code, you have to use
C<mount> for all the paths, including the root path (C</>). You can't
have the default app in the last line of C<builder> like:

    my $app = sub (%env) {
        ...
    };

    builder {
        mount "/foo", sub (%env) { ... };
        $app; # THIS DOESN'T WORK
    };

You'll get warnings saying that your mount configuration will be
ignored. Instead you should use C<< mount "/" => ... >> in the last
line to set the default fallback app.

    builder {
        mount "/foo", sub (%env) { ... };
        mount "/", $app;
    }

Note that the C<builder> DSL returns a whole new P6SGI application, which means

=item *

C<builder { ... }> should normally the last statement of a C<.p6sgi>
file, because the return value of C<builder> is the application that
is actually executed.

=item *

You can nest your C<builder> blocks, mixed with C<mount> statements (see L</"URLMap support">
above):

    builder {
        mount "/foo" => builder {
            mount "/bar" => $app;
        }
    }

will locate the C<$app> under C</foo/bar>, since the inner C<builder>
block puts it under C</bar> and it results in a new P6SGI application
which is located under C</foo> because of the outer C<builder> block.

=head1 CONDITIONAL MIDDLEWARE SUPPORT

You can use C<enable-if> to conditionally enable middleware based on
the runtime environment.

    builder {
        enable-if -> %env {
            %env<REMOTE_ADDR> eq '127.0.0.1'
        }, 'AccessLog', format => "combined";
        $app;
    };

See L<Crust::Middleware::Conditional> for details.

=head1 OBJECT ORIENTED INTERFACE

Object oriented interface supports the same functionality with the DSL
version in a clearer interface, probably with more typing required.

    # With mount
    my $builder = Crust::Builder.new;
    $builder.add-middleware('Foo', opt => 1);
    $builder.mount('/foo', $foo-app);
    $builder.mount('/', $root-app);
    $builder.to-app;

    # Nested builders. Equivalent to:
    # builder {
    #     mount '/foo', builder {
    #         enable 'Foo';
    #         $app;
    #     };
    #     mount '/' => $app2;
    # };

    my $builder-out = Crust::Builder.new;
    my $builder-in  = Crust::Builder.new;
    $builder-in.add-middleware('Foo');
    $builder-out.mount("/foo", $builder-in.wrap($app));
    $builder-out.mount("/", $app2);
    $builder-out.to-app;

    # conditional. You can also directly use Crust::Middleware::Conditional
    my $builder = Crust::Builder.new;
    $builder.add-middleware-if(sub (%sub) { %sub<REMOTE_ADDR> eq '127.0.0.1' }, 'AccessLog');
    $builder.wrap($app);

=head1 AUTHOR

moznion <moznion@gmail.com>

=head1 SEE ALSO

=item L<Crust::App::URLMap>

=item L<Crust::Middleware::Conditional>

=item L<Plack::Builder|https://metacpan.org/pod/Plack::Builder>

=end pod

