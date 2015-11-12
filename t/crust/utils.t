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
    is-deeply %opts, {
        name => 'upload',
        filename => 'hello.pl',
    };
}, 'parse-header-item';

subtest {
    my $dt = DateTime.new("2015-10-30T09:00:00+09:00");
    is $dt.offset, 9 * 3600; # sanity to make sure we are NOT in UTC...
    is format-datetime-rfc1123($dt), "Fri 30 Oct 2015 00:00:00 GMT";

    $dt = DateTime.new("2015-10-30T00:00:00z");
    is $dt.offset, 0; # sanity to make sure we are in UTC...
    is format-datetime-rfc1123($dt), "Fri 30 Oct 2015 00:00:00 GMT";

}, 'format-datetime-rfc1123';

done-testing;
