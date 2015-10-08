use v6;

unit class Crust::Headers;

use Hash::MultiValue;

has $!env = Hash::MultiValue.new;

# $env is PSGI's env header.
method new(Hash $env) {
    self.bless()!initialize($env);
}

method !initialize(Hash $env) {
    for $env.kv -> $k, $v {
        self.header($k, $v);
    }
    self;
}

multi method header(Str $key) {
    return $!env{$key.lc};
}

multi method header(Str $key, $val) {
    unless $val.defined {
        die "undefined value in header value: $key";
    }
    $!env{$key.lc} = $val.Str;
}

method content-type() {
    self.header('content-type');
}

method content-length() {
    self.header('content-length');
}

method content-encoding() {
    self.header('content-encoding');
}

method user-agent() {
    self.header('user-agent');
}

method referer() { self.header('referer') }

method Str() {
    $!env.all-kv.map(-> $k, $v { "$k: $v" }).join("\n");
}

=begin pod

=head1 NAME

Crust::Headers - headers

=head1 DESCRIPTION

This is a container class for list of HTTP headers.

=head1 METHODS

=head2 C<method new(Hash $env)>

Create new instance from hash.

=head2 C<multi method header(Str $key)>

Get header value by C<$key>.

=head2 C<multi method header(Str $key, $val)>

Set header value.

=head2 C<method content-type()>

Get content-type header's value.

=head2 C<method content-length()>

Get content-length header's value.

=head2 C<method content-encoding()>

Get content-encoding header's value.

=head2 C<method user-agent()>

Get user-agent header's value.

=head2 C<method referer()>

Get referer header's value.

=head1 AUTHORS

Tokuhiro Matsuno

=end pod
