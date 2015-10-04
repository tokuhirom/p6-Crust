use v6;
use Test;
use Crust::MIME;

sub x($t) { Crust::MIME.mime-type($t) }

is x(".gif"), "image/gif";
is x("foo.png"), "image/png";
is x("foo.GIF"), "image/gif";
ok !x("foo.bar").defined;
is x("foo.mp3"), "audio/mpeg";

done-testing;
