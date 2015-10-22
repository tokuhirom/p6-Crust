use v6;
use Crust::Middleware;

unit class Crust::Middleware::Runtime is Crust::Middleware;

has $.header-name = 'X-Runtime';

method CALL-ME(%env) {
    my $start = now;
    my @ret = $.app()(%env);

    my %headers = %(@ret[1]);
    %headers{$.header-name} = now - $start;
    @ret[1] = [%headers];

    return @ret;
}

=begin pod

=head1 NAME

Crust::Middleware::Runtime - Sets an X-Runtime response header

=head1 SYNOPSIS

  use Crust::Middleware::Runtime;

  my $app = sub { ... }; # your app
  $app = Crust::Middleware::Runtime.new($app);

  # or with your own header-name
  $app = Crust::Middleware::Runtime.new($app, :header-name<X-OWN-RUNTIME>);

Or use with builder

  enable 'Runtime';

=head1 DESCRIPTION

Crust::Middleware::Runtime is a middleware component that sets
the application's response time (in seconds) in the I<X-Runtime> HTTP response
header.

=head1 OPTIONS

=over 4

=item header_name

Name of the header. Defaults to I<X-Runtime>.

=back

=head1 SEE ALSO

=item L<Plack::Middleware::Runtime|https://metacpan.org/pod/Plack::Middleware::Runtime>

=head1 AUTHOR

Fayland Lam <fayland@gmail.com>

=end pod

