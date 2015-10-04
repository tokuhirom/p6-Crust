use v6;

# This file is a copy of https://github.com/zostay/p6-Hash-MultiValue/blob/master/lib/Hash/MultiValue.pm6.
# Hash::MultiValue is not working on latest rakudo.
# i sent patch for hash-multivalue. see https://github.com/zostay/p6-Hash-MultiValue/pull/2.
# I'll remove this file after merged p-r.

unit class Crust::MultiValue is Associative;

has @.all-pairs; #= Stores all keys and values for the hash
has %.singles = @!all-pairs.hash; #= Stores a simplified version of the hash with all keys, but only the last value

multi method add-pairs(@new is copy) {
    for @!all-pairs.kv -> $i, $v {
        next if $v.defined;
        @!all-pairs[$i] = @new.shift;
        last unless @new;
    }

    @!all-pairs.append: @new;
}

multi method add-pairs(*@new) {
    self.add-pairs(@new);
}

#| Construct a Crust::MultiValue object from an list of pairs
multi method from-pairs(@pairs) returns Crust::MultiValue {
    self.bless(all-pairs => @pairs);
}

#| Construct a Crust::MultiValue object from a list of pairs
multi method from-pairs(*@pairs) returns Crust::MultiValue {
    self.bless(all-pairs => @pairs);
}
#| Construct a Crust::MultiValue object from a mixed value hash
multi method from-mixed-hash(%hash) returns Crust::MultiValue {
    my @pairs = do for %hash.kv -> $k, $v {
        given $v {
            when Positional { .map($k => *).Slip }
            default         { $k => $v }
        }
    }
    self.bless(all-pairs => @pairs);
}

#| Construct a Crust::MultiValue object from a mixed value hash
multi method from-mixed-hash(*%hash) returns Crust::MultiValue {
    my $x = self.from-mixed-hash(%hash); # CALLWITH Y U NO WORK???
    return $x;
}

method AT-KEY($key) { 
    %!singles{$key} 
}

method ASSIGN-KEY($key, $value) { 
    @!all-pairs[ @!all-pairs.grep-index({ .defined && .key eqv $key }) ] :delete;
    self.add-pairs(($key => $value).list);
    %!singles{$key} = $value;
    $value;
}
method DELETE-KEY($key) {
    @!all-pairs[ @!all-pairs.grep-index({ .defined && .key eqv $key }) ] :delete;
    %!singles{$key} :delete;
}

method EXISTS-KEY($key) {
    %!singles{$key} :exists;
}
method postcircumfix:<( )>($key) is rw {
    my $self = self;
    my @all-pairs := @!all-pairs;
    Proxy.new(
        FETCH => method () { 
            @(@all-pairs.grep({ .defined && .key eqv $key })».value)
        },
        STORE => method (*@new) {
            @all-pairs[ @all-pairs.grep-index({ .defined && .key eqv $key }) ] :delete;
            $self.add-pairs: @new.map($key => *);
            $self.singles{$key} = @new[*-1];
            @new
        },
    )
}
method kv { %!singles.kv }
method pairs { %!singles.pairs }
method antipairs { %!singles.antipairs }
method invert { %!singles.invert }
method keys { %!singles.keys }
method values { %!singles.values }
method elems { %!singles.elems }
method all-kv { flat @!all-pairs».kv }
method all-pairs { flat @!all-pairs }
method all-antipairs { flat @!all-pairs».invert }
method all-invert { flat @!all-pairs».antipair }
method all-keys { flat @!all-pairs».key }
method all-values { flat @!all-pairs».value }
method all-elems { @!all-pairs.elems }

method push(*@values, *%values) {
    my %new-singles;
    my ($previous, Bool $has-previous);
    for flat @values, %values.pairs -> $v {
        if $has-previous {
            self.add-pairs: $previous => $v;
            %new-singles{ $previous } = $v;

            $has-previous--;
        }
        elsif $v ~~ Pair {
            self.add-pairs: $v.key => $v.value;
            %new-singles{ $v.key } = $v.value;
        }
        else {
            $has-previous++;
            $previous = $v;
        }
    }

    if ($has-previous) {
        warn "Trailing item in Crust::MultiValue.push";
    }

    %!singles = %!singles.Slip, %new-singles.Slip;
}
multi method perl(Crust::MultiValue:D:) returns Str { 
    "Crust::MultiValue.from-pairs(" 
        ~ @!all-pairs.grep(*.defined).sort(*.key cmp *.key).map(*.perl).join(", ") 
        ~ ")"
}

multi method gist(Crust::MultiValue:D:) {
    "Crust::MultiValue.from-pairs(" ~ 
        @!all-pairs.grep(*.defined).sort(*.key cmp *.key).map(-> $elem {
            given ++$ {
                when 101 { '...' }
                when 102 { last }
                default { $elem.gist }
            }
        }).join(", ") ~ ")"
}
