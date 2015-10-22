use v6;

use Crust::Middleware;

unit class Crust::Middleware::Conditional is Crust::Middleware;

has Callable $!condition;
has Callable $!builder;
has $!middleware;

submethod BUILD(:$app, *%opts) {
    $!condition  = %opts<condition>;
    $!builder    = %opts<builder>;
    $!middleware = $!builder.($app);
}

method CALL-ME(%env) {
    if $!condition(%env) {
        return $!middleware(%env);
    }

    return $.app()(%env);
}

=begin pod

=head1 NAME

Crust::Middleware::Conditional - Conditional wrapper for Crust middleware

=head1 SYNOPSIS

    use Crust::Builder;

    builder {
        enable-if -> %env {
            %env<REMOTE_ADDR> eq '127.0.0.1'
        }, "AccessLog", format => "combined";
        $app;
    };

    # or using the OO interface:
    use Crust::Middleware::Conditional;

    $app = Crust::Middleware::Conditional.new(
        $app,
        condition => -> %env {
            %env<REMOTE_ADDR> eq '127.0.0.1';
        },
        builder => -> $app {
            Crust::Middleware::AccessLog.new($app, format => "combined");
        },
    );

Or use with builder

    builder {
        enable-if -> %env { %env<REMOTE_ADDR> eq '127.0.0.1' }, 'AccessLog', :format('combined');
        $app;
    };

=head1 DESCRIPTION

Crust::Middleware::Conditional is a piece of meta-middleware, to run a
specific middleware component under runtime conditions. The goal of
this middleware is to avoid baking runtime configuration options in
individual middleware components, and rather share them as another
middleware component.

This middleware is inspired by L<Plack::Middleware::Conditional|https://metacpan.org/pod/Plack::Middleware::Conditional>.

=head1 AUTHOR

moznion <moznion@gmail.com>

=head1 SEE ALSO

=item L<Crust::Builder>

=item L<Plack::Middleware::Conditional|https://metacpan.org/pod/Plack::Middleware::Conditional>

=end pod

