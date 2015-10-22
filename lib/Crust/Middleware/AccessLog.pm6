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
    logger => sub { $io.print(@_) },
    format => "combined",
  }

Or use with builder

  enable 'AccessLog', :format('combined'), :logger(-> $log-line { ... });

=end pod

