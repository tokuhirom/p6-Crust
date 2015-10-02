use v6;

use Crust::Response;
use Test;

{
    my $resp = Crust::Response.new(status => 500, headers => ['Content-Type' => 'text/plain'], body => 'hoge');
    my $r = $resp.finalize();
    is $r[0], 500;
}

done-testing;
