use v6;
unit class Test::TCP;

sub wait_port(int $port, Str $host='127.0.0.1', :$sleep=0.1, int :$times=100) is export {
    LOOP: for 1..$times {
        try {
            my $sock = IO::Socket::INET.new(host => $host, port => $port);
            $sock.close;

            CATCH { default {
                sleep $sleep;
                next LOOP;
            } }
        }
        return;
    }

    die "$host:$port doesn't open in {$sleep*$times} sec.";
}


