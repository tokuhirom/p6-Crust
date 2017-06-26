use v6;
use Test;
use HTTP::Message::P6W;
use HTTP::Request;

{
    my $req = HTTP::Request.new(GET => "http://example.com/");
    my $env = $req.to-p6w;

    is $env<HTTP_HOST>, 'example.com';
    is $env<PATH_INFO>, '/';
}

{
    my $req = HTTP::Request.new(GET => "http://example.com:345/");
    my $env = $req.to-p6w;

    is $env<HTTP_HOST>, 'example.com:345';
    is $env<PATH_INFO>, '/';
}

{
    my $req = HTTP::Request.new(GET => "/");
    $req.field(Host => "perl.com");
    my $env = $req.to-p6w;

    is $env<HTTP_HOST>, 'perl.com';
    is $env<PATH_INFO>, '/';
}

done-testing;
