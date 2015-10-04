use v6;
use Test;
use Crust::MIME;

ok !Crust::MIME.mime-type(".vcd").defined;

my $fallback = sub ($file) { $file ~~ /\.vcd$/ ?? "application/x-cdlink" !! Nil };
Crust::MIME.set-fallback($fallback);
is Crust::MIME.mime-type(".vcd"), "application/x-cdlink";

done-testing;
