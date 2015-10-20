use v6;

unit class Crust::Request::Upload;

has Str $.filename;
has $.headers;
has IO::Path $.path;

=begin pod

=head1 NAME

Crust::Request::Upload - handles file upload requests

=head1 METHODS

=head2 filename

filename of the uploaded content.

=head2 headers

Returns headers for the part.

=head2 path

Returns the path to the temporary file where uploaded file is saved.

=end pod
