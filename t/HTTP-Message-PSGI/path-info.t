use v6;
use Test;
use HTTP::Message::PSGI;
use HTTP::Request;

my $env = HTTP::Request.new(GET => "http://localhost/foo").to-psgi;
is $env<PATH_INFO>, "/foo";

$env = HTTP::Request.new(GET => "http://localhost/").to-psgi;
is $env<SCRIPT_NAME>, "";
is $env<PATH_INFO>, "/";

$env = HTTP::Request.new(GET => "http://localhost/0").to-psgi;
is $env<SCRIPT_NAME>, "";
is $env<PATH_INFO>, "/0";

$env = HTTP::Request.new(GET => "http://localhost").to-psgi;
is $env<SCRIPT_NAME>, "";
is $env<PATH_INFO>, "/";
is $env<REQUEST_URI>, "/";


done-testing;
