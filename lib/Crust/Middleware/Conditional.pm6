use v6;

unit class Crust::Middleware::Conditional does Callable;

has Callable $.app;

has Callable $!condition;
has Callable $!builder;
has $!middleware;

submethod BUILD(:$app, *%opts) {
    $!app = $app;
    $!condition  = %opts<condition>;
    $!builder    = %opts<builder>;
    $!middleware = $!builder.($app);
}

method new(Callable $app, *%opts) {
    self.bless(app => $app, |%opts);
}

method CALL-ME(%env) {
    my $app = $!condition(%env) ?? $!middleware !! $!app;
    return $app.(%env);
}

=begin pod

=head1 NAME

Crust::Middleware::Conditional - Conditional wrapper for Crust middleware

=end pod

