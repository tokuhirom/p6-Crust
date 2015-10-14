use v6;
use Crust::Utils;
use Crust::App::URLMap;
use Crust::Middleware::Conditional;

unit class Crust::Builder;

has @!middlewares;
has $!url-map;

multi method add-middleware(Str $middleware, *%args) {
    my $middleware-class = load-class($middleware, 'Crust::Middleware');
    self.add-middleware(sub (*@args) {
        ::($middleware-class).new(@args[0], |%args);
    });
}

multi method add-middleware(Callable $middleware) {
    @!middlewares.push($middleware);
}

multi method add-middleware-if(Callable $condition, Str $middleware, *%args) {
    my $middleware-class = load-class($middleware, 'Crust::Middleware');
    self.add-middleware-if($condition, sub (*@args) {
        ::($middleware-class).new(@args[0], |%args);
    });
}

multi method add-middleware-if(Callable $condition, Callable $middleware) {
    @!middlewares.push(sub (*@args) {
        Crust::Middleware::Conditional.new(@args[0], :condition($condition), :builder($middleware));
    });
}

method !mount(Str $location, Callable $app) {
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

our $_add = our $_add-if = our $_mount = sub (*@args) {
    die "enable/mount should be called inside builder {} block";
}

sub enable($middleware, *%args) is export {
    $_add.($middleware, |%args);
}

sub enable-if(Callable $condition, $middleware, *%args) is export {
    $_add-if.($condition, $middleware, |%args);
}

sub mount(*@args) is export {
    $_mount.(@args);
}

sub builder(Callable $block) is export {
    my $builder = Crust::Builder.new;

    my $mount-is-called;
    my $url-map = Crust::App::URLMap.new;

    temp $_mount = sub (*@args) {
        $mount-is-called++;
        $url-map.map(|@args);
        return $url-map;
    };

    temp $_add = sub (*@args, *%params) {
        $builder.add-middleware(|@args, |%params);
    };

    temp $_add-if = sub (*@args, *%params) {
        $builder.add-middleware-if(|@args, |%params);
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

=pod start

=head1 Crust::Builder - Utility to enable Crust Middlewares

=pod end

