use v6;

unit module Crust::Utils;

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

