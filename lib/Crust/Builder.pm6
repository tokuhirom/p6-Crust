use v6;

unit class Crust::Builder;

has @.middlewares;

my Crust::Builder $builder;

method add-middleware(Crust::Builder:D: &cb) {
    @.middlewares.append(&cb);
}

method wrap-middlewares(Crust::Builder:D: &app) {
    my &ret = &app;
    for @.middlewares.reverse -> &mw {
        &ret = &mw(&ret);
    }
    return &ret;
}

multi sub enable(&cb) is export {
    $builder.add-middleware(&cb);
}

multi sub enable($name, *%args) is export {
    my $pkg = $name;
    my $found = $pkg.index("Crust::Middleware::");
    if !$found.defined || $found != 0 {
        $pkg = "Crust::Middleware::" ~ $pkg;
    }
    require ::($pkg);

    my &cb = sub (&app) {
        return ::($pkg).new(&app, |%args);
    }
    $builder.add-middleware(&cb);
}

sub builder(&cb) is export {
    temp $builder = Crust::Builder.new();
    my &app = &cb();
    &app = $builder.wrap-middlewares(&app);
    return &app;
}

