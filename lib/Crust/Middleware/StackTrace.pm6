use v6;
use Backtrace::AsHTML;
use Crust::Middleware;

unit class Crust::Middleware::StackTrace is Crust::Middleware;

has Bool $.no-print-errors = False;

method CALL-ME(%env) {
    my $ret = sub {
        return $.app()(%env);

        CATCH {
            my $trace = .backtrace;
            default {
                my $text = @$trace.map({ .Str.trim }).join("\n");
                my $html = $trace.as-html;
                %env<crust.stacktrace.text> = $text;
                %env<crust.stacktrace.html> = $html;

                %env<p6sgi.errors>.print($text) unless $.no-print-errors;
                if (%env<HTTP_ACCEPT> || '*/*') ~~ /'html'/ {
                    return 500, ['Content-Type' => 'text/html; charset=utf-8'], [ $html ];
                }
                return 500, ['Content-Type' => 'text/plain; charset=utf-8'], [ $text ];
            }
        }
    }();

    return $ret;
}

=begin pod

=head1 NAME

Crust::Middleware::StackTrace - Displays stack trace when your app dies

=head1 SYNOPSIS

  use Crust::Middleware::StackTrace;

  my $app = sub { ... }; # your app
  $app = Crust::Middleware::StackTrace.new($app);

Or use with builder

  enable 'StackTrace';

=head1 DESCRIPTION

Crust::Middleware::StackTrace catches exceptions of your application
and shows detailed stack trace for each exceptions.

The stack trace is also stored in the environment as a plaintext and HTML under the key
C<crust.stacktrace.text> and C<crust.stacktrace.html> respectively, so
that middleware further up the stack can reference it.

=head1 CONFIGURATION

=item C<Bool no-print-errors>

  $app = ::('Crust::Middleware::StackTrace').new(app => $app, no-print-errors => True);

Skips printing the text stacktrace to console (C<p6sgi.errors>).
Defaults to False, which means the text version of the
stack trace error is printed to the errors handle, which usually is a
standard error.

=head1 SEE ALSO

=item L<Plack::Middleware::StackTrace|https://metacpan.org/pod/Plack::Middleware::StackTrace>

=head1 AUTHOR

moznion <moznion@gmail.com>

=end pod

