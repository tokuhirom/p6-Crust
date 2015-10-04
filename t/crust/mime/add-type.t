use v6;
use Test;
use Crust::MIME;

Crust::MIME.add-type(".foo" => "text/foo");
is Crust::MIME.mime-type("bar.foo"), "text/foo";

Crust::MIME.add-type(".c" => "application/c-source");
is Crust::MIME.mime-type("FOO.C"), "application/c-source";

Crust::MIME.add-type(".a" => "text/a", ".b" => "text/b");
is Crust::MIME.mime-type("foo.a"), "text/a";
is Crust::MIME.mime-type("foo.b"), "text/b";

done-testing;
