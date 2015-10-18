use v6;
use Test;
use HTTP::Message::PSGI;
use IO::Blob;

subtest {
    my @psgi-res =
        404,
        ["Content-Length" => 9, 'X-Foo' => "hoge"],
        ["NOT FOUND"],
    ;
    my $res = HTTP::Response.from-psgi(|@psgi-res);
    is $res.code, 404;
    is $res.content, "NOT FOUND".encode('ascii');
    is $res.field('Content-Length'), 9;
    is $res.field('X-Foo'), "hoge";
};

subtest {
    my $io = IO::Blob.new( "hello".encode('utf-8') );
    my @psgi-res =
        200,
        [],
        $io,
    ;
    my $res = HTTP::Response.from-psgi(|@psgi-res);
    is $res.code, 200;
    is $res.content, "hello".encode('utf-8');
};

done-testing;
