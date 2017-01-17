use v6;

unit module Crust::Utils;

use MONKEY-SEE-NO-EVAL;

# internal use only. we'll change this file without notice.

sub parse-header-line(Str $header) is export {
    $header ~~ /^ (<-[: \s]>*) \s* \: \s* (.*) $/;
    return $/[0].Str.lc => $/[1].Str;
}

sub parse-header-item(Str $header) is export {
    my ($first, @items) = split(/\s*\;\s*/, $header);

    @items ==> map {
        $_ .= trim;
        my ($k, $v) = @(.split(/\=/));
        $v = $v.subst(/^\"(.*)\"$/, -> $/ { $/[0].Str });
        $k => $v
    } ==> my %opts;
    return $first.trim, %opts;
}

sub encode-html(Str $raw) is export {
    return $raw.trans(
        [ '&',     '<',    '>',    '"',      q{'}    ] =>
        [ '&amp;', '&lt;', '&gt;', '&quot;', '&#39;' ]
    );
}

sub status-with-no-entity-body(Int $status) returns Bool is export {
    return $status < 200 || $status == 204 || $status == 304;
}

sub content-length($body) is export {
    return Nil unless $body.defined;

    if $body.isa(List) {
        my $cl = 0;
        for @$body -> $chunk {
            my $length;
            given $chunk {
                when Str { $length = $chunk.encode.elems }
                when Blob { $length = $chunk.elems }
            }
            $cl += $length;
        }
        return $cl;
    } elsif $body.isa(IO::Handle) {
        return $body.s - $body.tell;
    }

    return Nil;
}

multi sub load-class($class) is export {
    # FIXME: workaround for Bug RT #130535
    # ref: https://github.com/tokuhirom/p6-Crust/pull/86
    EVAL "use $class";
    return $class;
}

multi sub load-class($class is copy, $prefix) is export {
    unless $class ~~ s/^'+'// || $class ~~ /^$prefix/ {
        $class = $prefix ~ '::' ~ $class;
    }
    return load-class($class);
}

multi sub format-datetime-rfc1123(Instant $i) is export {
    return format-datetime-rfc1123(DateTime.new($i))
}

multi sub format-datetime-rfc1123(DateTime $dt) is export {
    state @mon-abbr = <Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec>;
    state @dow-abbr = <Mon Tue Wed Thu Fri Sat Sun>;

    my $utc = $dt.utc;
    return sprintf("%s %02d %s %04d %02d:%02d:%02d GMT",
        @dow-abbr[$utc.day-of-week - 1],
        $utc.day-of-month, @mon-abbr[$utc.month-1], $utc.year,
        $utc.hour, $utc.minute, $utc.second);
}


