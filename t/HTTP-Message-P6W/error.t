use v6;
use Test;
use HTTP::Message::P6W;
use HTTP::Request;
use IO::Blob;

my $io = IO::Blob.new();
$*ERR = $io;

my $env = HTTP::Request.new(GET => "http://localhost/").to-p6w;
isa-ok $env<p6w.errors>, Supplier;

lives-ok { $env<p6w.errors>.emit('ohno'); }, 'can emit';

$io.seek(0);
is $io.slurp-rest, "ohno\n";

done-testing;
