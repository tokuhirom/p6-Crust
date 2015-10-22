use v6;

use Apache::LogFormat;
use Crust::Middleware;

unit class Crust::Middleware::AccessLog is Crust::Middleware;

has $.formatter;
has &.logger;

method new(Callable $app, *%opts) {
    my Apache::LogFormat::Formatter $formatter;
    given %opts<format> {
    when any(!.Bool, "combined")
        { $formatter = Apache::LogFormat.combined }
    when "common"   { $formatter = Apache::LogFormat.common }
    when Apache::LogFormat::Compiler {
        $formatter = %opts<format>;
    }
    default {
        my $c = Apache::LogFormat::Compiler.new();
        $formatter = $c.compile(%opts<format>);
    }
    }
    %opts<format>:delete;

    %opts<formatter> = $formatter;
    callwith($app, |%opts);
}

my sub content-length(@res) {
    for @(@res[1]) -> $pair {
        if $pair.key.lc eq 'content-length' {
            return $pair.value;
        }
    }
    return "-";
}

method CALL-ME(%env) {
    my $t0 = DateTime.now.Instant;
    my @res = $.app()(%env);

    # '%h %l %u %t "%r" %>s %b "%{Referer}i" "%{User-agent}i"'
    my $logger = $.logger;
    if !$logger.defined {
        $logger = sub ($s) { %env<p6sgi.errors>.print($s) };
    }

    my $cl = content-length(@res);
    my $now = DateTime.now;
    my $line = $.formatter().format(%env, @res, $cl, $now.Instant - $t0, $now);
    $logger($line);

    return @res;
}


=begin pod

=head1 NAME

Crust::Middleware::AccessLog - Middleware To Generate Access Logs

=head1 SYNOPSIS

    my &app = sub(%env) { ... };
    my $code = Crust::Middleware::AccessLog.new(
        &app,
        :format('combined'),
        :logger(-> $s { $io.print($s) }),
    }

Or use with builder

    enable 'AccessLog', :format('combined'), :logger(-> $log-line { ... });

=head1 DESCRIPTION

Crust::Middleware::AccessLog forwards the request to the given app and
logs request and response details to the logger callback. The format
can be specified using Apache-like format strings (or C<combined> or
C<common> for the default formats). If none is specified C<combined> is
used.

This middleware is enabled by default when you run L<crustup> as a
default C<development> environment.

=head1 CONFIGURATION

=item format :Str

    enable "AccessLog", :format('combined');
    enable "AccessLog", :format('common');
    enable "AccessLog", :format('%h %l %u %t "%r" %>s %b "%{Referer}i" "%{User-agent}i"');

Takes a format string (or a preset template C<combined> or C<custom>)
to specify the log format. This middleware uses L<Apache::LogFormat::Compiler> to
generate access_log lines. See more details on perldoc L<Apache::LogFormat::Compiler>

=item logger :Callable

    my $logger = ...; # some logging tool
    enable "AccessLog",
        :logger(-> sub ($s) { $logger->log($s ... ) };

Sets a callback to print log message to. It prints to the C<p6sgi.errors>
output stream by default.

=head1 AUTHORS

Daisuke Maki

=head1 SEE ALSO

L<Apache::LogFormat::Compiler>, L<http://httpd.apache.org/docs/2.2/mod/mod_log_config.html>

=end pod

