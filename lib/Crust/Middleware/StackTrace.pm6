use v6;
use Backtrace::AsHTML;

unit class Crust::Middleware::StackTrace does Callable;

has $.app;

has Bool $.no-print-errors = False;

method CALL-ME(%env) {
    my $ret = sub {
        return $.app()(%env);

        CATCH {
            my $trace = .backtrace;
            default {
                my $text = @$trace.map({ .Str.trim }).join("\n");
                my $html = $trace.as-html;
                %env<p6sgi.stacktrace.text> = $text;
                %env<p6sgi.stacktrace.html> = $html;

                %env<p6sgi.error>.print($text) unless $.no-print-errors;
                if (%env<HTTP_ACCEPT> || '*/*') ~~ /'html'/ {
                    return [500, ['Content-Type' => 'text/html; charset=utf-8'], [ $html ]];
                }
                return [500, ['Content-Type' => 'text/plain; charset=utf-8'], [ $text ]];
            }
        }
    }();

    return $ret;
}

