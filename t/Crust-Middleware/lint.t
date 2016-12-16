use v6;
use Test;

use Crust::Middleware::Lint;

my %env = (
    :REQUEST_METHOD<GET>,
    :SCRIPT_NAME<foobar>,
    :PATH_INFO</foo/bar>,
    :SERVER_NAME<server_name>,
    :SERVER_PORT<8080>,
    :SERVER_PROTOCOL<HTTP/1.1>
);

subtest {
    my $code = Crust::Middleware::Lint.new(
        sub (%env) {
            200, [], ['hello']
        }
    );

    lives-ok({$code(%env)}, 'Should work fine');

    subtest {
        temp %env = %env;
        %env<REQUEST_METHOD>:delete;
        dies-ok({$code(%env)});
    }, 'Should die because REQUEST_METHOD is missing';

    subtest {
        temp %env = %env;
        %env<REQUEST_METHOD> = '666';
        dies-ok({$code(%env)});
    }, 'Should die besause REQUEST_METHOD is invalid';

    subtest {
        temp %env = %env;
        %env<SCRIPT_NAME>:delete;
        dies-ok({$code(%env)});
    }, 'Shuold die because SCRIPT_NAME is missing';

    subtest {
        temp %env = %env;
        %env<SCRIPT_NAME> = '/';
        dies-ok({$code(%env)});
    }, 'Shuold die because SCRIPT_NAME equals /';

    subtest {
        temp %env = %env;
        %env<PATH_INFO>:delete;
        dies-ok({$code(%env)});
    }, 'Should die because PATH_INFO is missing';

    subtest {
        temp %env = %env;
        %env<PATH_INFO> = 'not-begin-with-slash';
        dies-ok({$code(%env)});
    }, 'Should die because PATH_INFO is invalid';

    subtest {
        temp %env = %env;
        %env<SERVER_NAME>:delete;
        dies-ok({$code(%env)});
    }, 'Should die because SERVER_NAME is missing';

    subtest {
        temp %env = %env;
        %env<SERVER_NAME> = '';
        dies-ok({$code(%env)});
    }, 'Should die because SERVER_NAME is empty';

    subtest {
        temp %env = %env;
        %env<SERVER_PORT>:delete;
        dies-ok({$code(%env)});
    }, 'Should die because SERVER_PORT is missing';

    subtest {
        temp %env = %env;
        %env<SERVER_PORT> = '';
        dies-ok({$code(%env)});
    }, 'Should die because SERVER_PORT is empty';

    subtest {
        temp %env = %env;
        %env<SERVER_PROTOCOL> = 'MY-FABULOUS-PROTOCOL';
        dies-ok({$code(%env)});
    }, 'Should die because SERVER_PROTOCOL is invalid';

    subtest {
        temp %env = %env;
        %env<HTTP_CONTENT_TYPE> = 'text/html';
        dies-ok({$code(%env)});
    }, 'Should die because HTTP_CONTENT_TYPE is existed';

    subtest {
        temp %env = %env;
        %env<HTTP_CONTENT_LENGTH> = 666;
        dies-ok({$code(%env)});
    }, 'Should die because HTTP_CONTENT_LENGTH is existed';
}, 'Test for env validation';

subtest {
    subtest {
        my $code = Crust::Middleware::Lint.new(
            sub (%env) {
                200, [
                    'Content-Type' => 'text/plain',
                    'Content-Length' => 123,
                ], ['hello']
            }
        );
        lives-ok({$code(%env)});
    }, 'Should works fine';

    subtest {
        my $code = Crust::Middleware::Lint.new(
            sub (%env) { 200, [] }
        );
        dies-ok({$code(%env)});
    }, 'Should die because response does not have enough elements';

    subtest {
        my $code = Crust::Middleware::Lint.new(
            sub (%env) { 'status!!', [], ['hello'] }
        );
        dies-ok({$code(%env)});
    }, 'Should die because response has not numerical status code';

    subtest {
        my $code = Crust::Middleware::Lint.new(
            sub (%env) { 42, [], ['hello'] }
        );
        dies-ok({$code(%env)});
    }, 'Should die because response status code is less than 100';

    subtest {
        my $code = Crust::Middleware::Lint.new(
            sub (%env) { 200, 'invalid-header', ['hello'] }
        );
        dies-ok({$code(%env)});
    }, 'Should die because response header is not Array';

    subtest {
        my $code = Crust::Middleware::Lint.new(
            sub (%env) { 200, ['invalid'], ['hello'] }
        );
        dies-ok({$code(%env)});
    }, 'Should die because response header has odd elements';

    subtest {
        my $code = Crust::Middleware::Lint.new(
            sub (%env) { 200, ['Status' => 'Fine'], ['hello'] }
        );
        dies-ok({$code(%env)});
    }, 'Should die because response header has status field';

    subtest {
        {
            my $code = Crust::Middleware::Lint.new(
                sub (%env) { 200, ['foo:bar' => 'buz'], ['hello'] }
            );
            dies-ok({$code(%env)});
        }
        {
            my $code = Crust::Middleware::Lint.new(
                sub (%env) { 200, ['foobar-' => 'buz'], ['hello'] }
            );
            dies-ok({$code(%env)});
        }
        {
            my $code = Crust::Middleware::Lint.new(
                sub (%env) { 200, ['0foobar' => 'buz'], ['hello'] }
            );
            dies-ok({$code(%env)});
        }
        {
            my $code = Crust::Middleware::Lint.new(
                sub (%env) { 200, ['foo$bar' => 'buz'], ['hello'] }
            );
            dies-ok({$code(%env)});
        }
    }, 'Should die because response header has invalid field';

    subtest {
        my $code = Crust::Middleware::Lint.new(
            sub (%env) { 200, ['something' => utf8.new(0).Str], ['hello'] }
        );
        dies-ok({$code(%env)});
    }, 'Should die because value of response header has invalid character';

    subtest {
        my $code = Crust::Middleware::Lint.new(
            sub (%env) { 200, ['something' => Nil], ['hello'] }
        );
        dies-ok({$code(%env)});
    }, 'Should die because value of response header is undefined';

    subtest {
        my $code = Crust::Middleware::Lint.new(
            sub (%env) { 200, [], {} }
        );
        dies-ok({$code(%env)});
    }, 'Should die because response body is invalid type';
}, 'Test for ret validation';

done-testing;

