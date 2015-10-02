use v6;

use Test;

use Crust::Utils;

subtest  {
    my $pair = parse-header-line("foo: bar");
    is $pair.key, 'foo';
    is $pair.value, 'bar';
}, 'parse-header-line';

subtest {
    my ($head, %opts) = parse-header-item('form-data; name="upload"; filename="hello.pl"');
    is $head, 'form-data';
    is %opts, (
        name => 'upload',
        filename => 'hello.pl',
    );
}, 'parse-header-item';

done-testing;
