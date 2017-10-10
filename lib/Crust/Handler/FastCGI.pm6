use v6;

unit class Crust::Handler::FastCGI;

require FastCGI::NativeCall::PSGI;

has $!psgi;

proto method new(|c) { * }

multi method new(Int:D :$sock!) {
    self.bless()!initialize(:$sock);
}

multi method new(*%args) {
    my $path = %args<path> // %args<socket> // %*ENV<FCGI_SOCKET> // '/var/www/run/p6w-fcgi.sock';
    my $backlog = %args<backlog> // %*ENV<FCGI_BACKLOG> // 5;
    self.bless()!initialize(:$path, :$backlog);
}

method !initialize(:$path,:$backlog, :$sock) {
    $!psgi = do {
        if $sock.defined {
            ::("FastCGI::NativeCall::PSGI").new(:$sock);
        }
        else {
            ::("FastCGI::NativeCall::PSGI").new(:$path, :$backlog);
        }
    };
    self;
}

method run(Crust::Handler::FastCGI:D: Callable $app) {
    $!psgi.app($app);
    $!psgi.run;
}

=begin pod

=head1 NAME

Crust::Handler::FastCGI - Crust adapter for FastCGI::NativeCall::PSGI

=head1 SYNOPSIS

    crustup \
        -s FastCGI -MFastCGI::NativeCall::PSGI \
        [--socket /PATH/TO/APP.SOCK] [--backlog INT] \
        app.p6w

=end pod
