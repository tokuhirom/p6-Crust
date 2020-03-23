use v6;

use Test;
use Crust::Request;

# body-parameters: multipart/form-data
subtest {
    my $req = Crust::Request.new({
        :REMOTE_ADDR<127.0.0.1>,
        'p6w.input' => open('t/crust/data/001-content.dat', :bin).Supply,
        :HTTP_USER_AGENT<hoge>,
        :HTTP_REFERER<http://mixi.jp>,
        :HTTP_CONTENT_ENCODING<gzip>,
        REQUEST_URI => '/iyan?foo=bar&foo=baz',
        QUERY_STRING => 'foo=bar&foo=baz',
        PATH_INFO => '/iyan',
        HTTP_HOST => 'example.com',
        CONTENT_TYPE => 'multipart/form-data; boundary="----------0xKhTmLbOuNdArY"',
    });
    my $params = $req.body-parameters;
    is $params<text1>.decode('ascii'), 'Ratione accusamus aspernatur aliquam';
    is $req.uploads.keys.sort.join(','), 'upload,upload1,upload2,upload3,upload4';
    is $req.uri, 'http://example.com/iyan?foo=bar&foo=baz';
    is $req.request-uri, '/iyan?foo=bar&foo=baz';
    my $upload2 = $req.uploads<upload2>;
    is $upload2.filename, 'hello.pl';
    ok $upload2.path.slurp(:bin).decode('ascii') ~~ m:s/Hello World/;
}, 'multipart/form-data';

# content
subtest {
    my $req = Crust::Request.new({
        :REMOTE_ADDR<127.0.0.1>,
        'p6w.input' => open('t/crust/data/001-content.dat', :bin).Supply,
        :HTTP_USER_AGENT<hoge>,
        :HTTP_REFERER<http://mixi.jp>,
        :HTTP_CONTENT_ENCODING<gzip>,
        REQUEST_URI => '/iyan?foo=bar&foo=baz',
        QUERY_STRING => 'foo=bar&foo=baz',
        PATH_INFO => '/iyan',
        HTTP_HOST => 'example.com',
        CONTENT_TYPE => 'multipart/form-data; boundary="----------0xKhTmLbOuNdArY"',
    });
    my $content = $req.content;
    ok $content.decode('ascii') ~~ m:s/Hello World/;
}, 'Request#content';

subtest {
    my $req = Crust::Request.new({
        :REMOTE_ADDR<127.0.0.1>,
        :QUERY_STRING<foo=bar&foo=baz>,
        'p6w.input' => open('t/crust/request.t', :bin).Supply,
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
    ok $req.content.decode('ascii') ~~ /"p6w.input"/; # XXX better method?
    is $req.parameters<foo>, 'baz';
    is $req.base, 'http://example.com/';
    is $req.uri, 'http://example.com/?foo=bar&foo=baz';
}, 'query params and basic things';

# body-parameters: x-www-form-urlencoded
subtest {
    my $req = Crust::Request.new({
        :REMOTE_ADDR<127.0.0.1>,
        :QUERY_STRING<foo=bar&foo=baz>,
        'p6w.input' => open('t/dat/query.txt', :bin).Supply,
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
    my $cookies = $req.cookies;
    my $hoge = $cookies<hoge>;
    is $hoge, 'fuga';
}, 'body-params';

done-testing;
