use v6;

unit class Crust::Middleware does Callable;

has Callable $.app;

method new(Callable $app, *%opts) {
    self.bless(app => $app, |%opts);
}

multi method wrap(Crust::Middleware:D: Callable $app) {
    self.$!app = $app;
}

multi method wrap(Crust::Middleware:U: Callable $app, *%opts) {
    return self.new($app, |%opts)
}
