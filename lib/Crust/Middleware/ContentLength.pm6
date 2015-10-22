use v6;
use Crust::Middleware;
use Crust::Utils;

unit class Crust::Middleware::ContentLength is Crust::Middleware;

method CALL-ME(%env) {
    my @ret = $.app()(%env);

    my %headers = %(@ret[1]);
    if (
        !status-with-no-entity-body(@ret[0]) &&
        !%headers<Content-Length>.defined &&
        !%headers<Transfer-Encoding>.defined &&
        (my $content-length = content-length(@ret[2])).defined
    ) {
        %headers<Content-Length> = $content-length;
    }
    @ret[1] = [%headers];

    return @ret;
}

=begin pod

=head1 NAME

Crust::Middleware::ContentLength - Adds Content-Length header automatically

=head1 SYNOPSIS

  use Crust::Middleware::ContentLength;

  my $app = sub { ... }; # your app
  $app = Crust::Middleware::ContentLength.new($app);

Or use with builder

  enable 'ContentLength';

=head1 DESCRIPTION

Crust::Middleware::ContentLength is a middleware that automatically
adds C<Content-Length> header when it's appropriate i.e. the response
has a content body with calculable size (array of chunks or a filehandle).

=head1 SEE ALSO

=item L<Plack::Middleware::ContentLength|https://metacpan.org/pod/Plack::Middleware::ContentLength>

=item Rack::ContentLength

=head1 AUTHOR

moznion <moznion@gmail.com>

=end pod

