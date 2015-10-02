use v6;

use Test;
use Crust::Request;
use Hash::MultiValue;

# body-parameters: multipart/form-data
subtest {
    my $req = Crust::Request.new({
        :REMOTE_ADDR<127.0.0.1>,
        :QUERY_STRING<foo=bar&foo=baz>,
        'psgi.input' => open('t/crust/data/001-content.dat', :bin),
        :HTTP_USER_AGENT<hoge>,
        :HTTP_REFERER<http://mixi.jp>,
        :HTTP_CONTENT_ENCODING<gzip>,
        HTTP_HOST => 'example.com',
        CONTENT_TYPE => 'multipart/form-data; boundary="----------0xKhTmLbOuNdArY"',
    });
    my $params = $req.body-parameters;
    is $params<text1>.decode('ascii'), 'Ratione accusamus aspernatur aliquam';
    is $req.uploads.keys.sort.join(','), 'upload,upload1,upload2,upload3,upload4';
    my $upload2 = $req.uploads<upload2>;
    is $upload2.filename, 'hello.pl';
    ok $upload2.path.slurp(:bin).decode('ascii') ~~ m:s/Hello World/;
}, 'multipart/form-data';

subtest {
    my $req = Crust::Request.new({
        :REMOTE_ADDR<127.0.0.1>,
        :QUERY_STRING<foo=bar&foo=baz>,
        'psgi.input' => open('t/crust/request.t'),
        :HTTP_USER_AGENT<hoge>,
        :HTTP_REFERER<http://mixi.jp>,
        :HTTP_CONTENT_ENCODING<gzip>,
        :HTTP_HOST<example.com>,
        :CONTENT_TYPE<text/html>
    });
    is $req.address, '127.0.0.1';
    my $p = $req.query-parameters;
    ok [$p.all-pairs] eqv [:foo<bar>, :foo<baz>];
    is $req.headers.content-type, 'text/html';
    is $req.header('content-type'), 'text/html';
    is $req.user-agent, 'hoge';
    is $req.referer, 'http://mixi.jp';
    is $req.content-encoding, 'gzip';
    ok $req.content.decode('ascii') ~~ /"psgi.input"/; # XXX better method?
    is $req.parameters<foo>, 'baz';
    is $req.base, 'http://example.com/';
}, 'query params and basic things';

# body-parameters: x-www-form-urlencoded
subtest {
    my $req = Crust::Request.new({
        :REMOTE_ADDR<127.0.0.1>,
        :QUERY_STRING<foo=bar&foo=baz>,
        'psgi.input' => open('t/dat/query.txt'),
        :HTTP_USER_AGENT<hoge>,
        :CONTENT_TYPE<application/x-www-form-urlencoded>
    });
    is $req.body-parameters<iyan>, 'bakan';
    is $req.parameters<foo>, 'baz';
    is $req.parameters<iyan>, 'bakan';
}, 'body-params';

# cookies
subtest {
    my $req = Crust::Request.new({
        :HTTP_COOKIE<hoge=fuga>
    });
    $req.cookies.perl; # magical trash. if you remove this, this test fails.
    my $cookies = $req.cookies;
    my $hoge = $cookies<hoge>;
    is $hoge, 'fuga';
}, 'body-params';

done-testing;
