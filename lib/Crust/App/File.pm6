use v6;
unit class Crust::App::File does Callable;
use Crust::MIME;
use Crust::Utils;

# TODO: need to set path-info for Crust::App::CGIBin etc...

has Str $.root;
has Str $.file;
has $.content-type; # Could be Str/Callable
has Str $.encoding;

method should-handle(Str $file) {
    $file.IO.f;
}

method CALL-ME($env) {
    self.call($env);
}

method call(Hash $env) {
    my ($file, $path-info, $error-res) = $!file || self.locate-file($env);
    return |$error-res if $error-res;

    return self.serve-path($env, $file);
}

method locate-file(Hash $env) {
    my $path = $env<PATH_INFO> || '';
    if $path ~~ /\0/ {
        return Nil, Nil, self!return_400;
    }

    my $docroot = $!root || ".";
    my @path = $path.split(/<[\\/]>/);

    if @path {
        @path.shift if @path[0] eq '';
    } else {
        @path = ".";
    }

    if grep /^ \. ** 2 /, @path {
        return Nil, Nil, self!return_403;
    }

    my ($file, @path-info);
    while @path {
        my $try = IO::Spec::Unix.catfile($docroot, |@path);
        if self.should-handle($try) {
            $file = $try;
            last;
        } elsif !self.allow-path-info {
            last;
        }
        @path-info.unshift( @path.pop );
    }
    unless $file {
        return Nil, Nil, self!return_404;
    }
    unless $file.IO.r {
        return Nil, Nil, self!return_403;
    }

    return $file, join("/", "", |@path-info);
}

method allow-path-info() { False }

method serve-path(Hash $env, Str $file) {
    my $content-type = $!content-type || Crust::MIME.mime-type($file) || 'text/plain';
    if $content-type ~~ Callable {
        $content-type = $content-type($file);
    }

    if $content-type ~~ /^ text '/' / {
        $content-type ~= "; charset=" ~ ( $!encoding || "utf-8" );
    }

    my $fh = try { open $file, :bin } or self!return_403;

    return
        200,
        [
            'Content-Type' => $content-type,
            'Content-Length' => $file.IO.s,
            'Last-Modified' => format-datetime-rfc1123(DateTime.new($file.IO.modified)),
        ],
        $fh,
    ;
}

method !return_403() {
    return 403, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['forbidden'];
}
method !return_400() {
    return 400, ['Content-Type' => 'text/plain', 'Content-Length' => 11], ['Bad Request'];
}
method !return_404() {
    return 404, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['not found'];
}

=begin pod

=head1 NAME

Crust::App::File - Serve static files from root directory

=head1 SYNOPSIS

  > crustup -MCrust::App::File -e 'Crust::App::File.new'

=head1 DESCRIPTION

Crust::App::File is perl6 port of perl5 Plack::App::File.

=head1 SEE ALSO

L<Plack::App::File|https://metacpan.org/pod/Plack::App::File>

=head1 AUTHOR

Shoichi Kaji

=head1 ORIGNAL AUTHOR

This module is port of Perl5's Palck::App::File.
Tatsuhiko Miyagawa is an original author of Plack::App::File.

=end pod
