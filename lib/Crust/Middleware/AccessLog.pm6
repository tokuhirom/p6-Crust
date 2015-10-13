use v6;

unit class Crust::Middleware::AccessLog does Callable;

has $.app;
has Callable $.logger;

method new(Callable $app, *%opts) {
    self.bless(app => $app, |%opts);
}

# TODO: configurable access log format
# TODO: Port Apache::LogFormat::Compile from Perl5.

my sub content-length(@ret) {
    for @(@ret[1]) -> $pair {
        if $pair.key.lc eq 'content-length' {
            return $pair.value;
        }
    }
    return "-";
}

my @WDAY = <Sun Mon Tue Wed Thu Fri Sat Sun>;
my @MON = <Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec>;

# [10/Oct/2000:13:55:36 -0700]
my sub format-datetime(DateTime $dt) {
    return sprintf("%02d/%s/%04d:%02d:%02d:%02d %s%02d%02d",
        $dt.day-of-month, @MON[$dt.month-1], $dt.year,
        $dt.hour, $dt.minute, $dt.second, ($dt.offset>0??'+'!!'-'), $dt.offset/3600, $dt.offset%3600);
}

method CALL-ME(%env) {
    my @ret = $.app()(%env);

    # '%h %l %u %t "%r" %>s %b "%{Referer}i" "%{User-agent}i"'
    my $logger = $.logger;
    if !$logger.defined {
        $logger = sub { %env<p6sgi.error>.print(@_) };
    }

    $logger(sprintf(
        "%s - %s [%s] \"%s %s %s\" %s %s \"%s\" \"%s\"\n",
        %env<REMOTE_ADDR>//'-', # %h
        %env<REMOTE_USER> // '-', # %u
        format-datetime(DateTime.now), # %t
        %env<REQUEST_METHOD> // '-',
        %env<REQUEST_URI> // '-',
        %env<SERVER_PROTOCOL> // '-',
        @ret[0].Str,
        content-length(@ret),
        %env<HTTP_REFERER> // '-',
        %env<HTTP_USER_AGENT> // '-',
    ));

    return @ret;
}

