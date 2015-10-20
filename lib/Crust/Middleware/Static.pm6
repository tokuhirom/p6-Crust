use v6;
use Crust::App::File;
use Crust::Middleware;

unit class Crust::Middleware::Static is Crust::Middleware;

has $.file;
has $.path;
has $.root;
has $.encoding;
has $.pass-through;
has $.content-type;

submethod BUILD(:$!path, :$!root, :$!encoding, :$!content-type, :$!pass-through) {
    $!path //= sub ($path, %env) { return True, $path };
    $!root //= ".";
    $!encoding //= "iso-8859-1";
    $!content-type //= "";
    $!file = Crust::App::File.new(
        :root($!root),
        :encoding($!encoding),
        :content-type($!content-type),
    );
}

method CALL-ME(%env) {
    my @res = self!handle-static(%env);
    if @res && ! ($.pass-through && @res[0] == 404) {
        return @res;
    }

    return $.app.(%env);
}

method !handle-static(%env) {
    my $path_match = $.path;
    if ! $path_match.defined {
        return ();
    }

    my $path = %env<PATH_INFO>;
    my $proceed;

    given $path_match {
        when Regex { $proceed = $path ~~ $path_match }
        when Callable { ($proceed, $path) = $path_match($path, %env) }
    }

    if !$proceed {
        return ();
    }

    temp %env<PATH_INFO> = $path;
    my @res = $!file.(%env);
    return @res;
}