use v6;

unit class Crust::Middleware does Callable;

has Callable $.app;

method new(Callable $app, |opts) {
    self.bless(app => $app, |opts);
}
