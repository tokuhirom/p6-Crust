use v6;

unit class Crust::Response;

has int $.status;
has Array $.headers;
has $.body;

method finalize() {
    return [ $.status, $.headers, $.body ];
}
