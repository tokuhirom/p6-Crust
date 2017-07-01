class SupplierBuffer {
    has $.supplier;
    has $.result = "";

    method new() {
        my $supplier = Supplier.new;
        my $self = self.bless(supplier => $supplier);
        my $supply = $supplier.Supply;
        $supply.tap(-> $v { $self.append($v) });
        return $self;
    }

    method append($v) {
        $!result ~= $v if $v;
    }
}

