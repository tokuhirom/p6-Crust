use v6;
use Test;

use Crust::Builder;
use Crust::Middleware::ErrorDocument;
use Crust::Middleware::AccessLog;

my $app = sub () {
    return 500, [], ["OK"];
}

builder {
    enable 'ErrorDocument', :sub-request => 'bar', 500 => 'foo.html';
    enable 'AccessLog', :format('combined'), :logger(-> $log-line { ... });
    $app;
};

ok True;

done-testing;
