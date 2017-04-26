use v6;
use Crust::App::File;
use Crust::MIME;
use Crust::Utils;

unit class Crust::App::Directory is Crust::App::File;

our $dir_file = Q:b "<tr><td class='name'><a href='%s'>%s</a></td><td class='size'>%s</td><td class='type'>%s</td><td class='mtime'>%s</td></tr>";
our $dir_page = Q:to 'PAGE';
<html><head>
  <title>%s</title>
  <meta http-equiv="content-type" content="text/html; charset=utf-8" />
  <style type='text/css'>
table { width:100%%; }
.name { text-align:left; }
.size, .mtime { text-align:right; }
.type { width:11em; }
.mtime { width:15em; }
  </style>
</head><body>
<h1>%s</h1>
<hr />
<table>
  <tr>
    <th class='name'>Name</th>
    <th class='size'>Size</th>
    <th class='type'>Type</th>
    <th class='mtime'>Last Modified</th>
  </tr>
%s
</table>
<hr />
</body></html>
PAGE

has Str $.dir;

method should-handle(Str $dir) {
    $dir.IO.d || $dir.IO.f;
}

method call(Hash $env) {
    # Directory traversal should be avoided by Crust::App::File.locate-file.
    # It should be returned as the root directory.
    my ($file, $path-info, $error-res) = $!dir || self.locate-file($env);
    return |$error-res if $error-res;

    return self.serve-path($env, $file) if $file.IO.f;
    return self.serve-dir($env, $file);
}

method serve-dir(Hash $env, Str $dir) {
    my $path = $env<PATH_INFO> || '';
    return
        301,
        [
            'Content-Type' => "text/plain",
            'Location' => "/{{$dir}}/"
        ],
        [""] unless $path.ends-with('/');

    my Str $files;
    $files ~= sprintf($dir_file, '..', '..', '', '', '');
    for $dir.IO.dir -> $file {
        my $ct = $file.d ?? '' !! Crust::MIME.mime-type($file.absolute) || 'text/plain';
        my $size = $file.d ?? '' !! $file.s;
        my $name = encode-html($file.basename);
        $files ~= sprintf($dir_file, $name, $name, $size, $ct, DateTime.new($file.modified));
    }

    my $page = sprintf($dir_page, $path, $path, $files);
    return
        200,
        [
            'Content-Type' => 'text/html; charset=utf-8'
        ],
        [$page]
    ;
}

=begin pod

=head1 NAME

Crust::App::Directory - Serve static files from document root with directory index

=head1 SYNOPSIS

  > crustup -MCrust::App::Directory -e 'Crust::App::Directory.new'

=head1 DESCRIPTION

Crust::App::Directory is perl6 port of perl5 Plack::App::Directory.

=head1 SEE ALSO

L<Plack::App::Directory|https://metacpan.org/pod/Plack::App::Directory>

=head1 AUTHOR

Yasuhiro Matsumoto

=head1 ORIGNAL AUTHOR

This module is port of Perl5's Palck::App::Directory.
Tatsuhiko Miyagawa is an original author of Plack::App::Directory.

=end pod
