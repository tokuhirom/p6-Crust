use v6;

unit class Crust::Request::Upload;

has Str $.filename;
has Str $.name;
has IO::Path $.path;

