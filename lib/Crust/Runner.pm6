use v6;

unit class Crust::Runner;

use Getopt::Tiny;
use MONKEY-SEE-NO-EVAL;

has @!inc;

has &!app;
has %!options = host => '127.0.0.1', port => 5000;
has @!args;

has Bool $!accesslog;
has @!modules;
has Str $!eval;
has Bool $!lint;
has Str  $!server = 'HTTP::Server::Tiny';

method parse-options(@args) {
    my $opts = {
        I => [],
        M => [],
        s => 'HTTP::Server::Tiny',
    };

    my Bool $version;

    @args = Getopt::Tiny.new(:pass-through)
        .str( 'e', Nil,         { $!eval           =  $^a })
        .str( 'I', Nil,         { @!inc.push:         $^a })
        .str( 'M', Nil,         { @!modules.push:     $^a })
        .bool(Nil, 'accesslog', { $!accesslog       = $^a })
        .bool(Nil, 'lint',      { $!lint            = $^a })
        .bool('v', 'version',   { $version          = $^a })
        .str( 'h', 'host',      { %!options{'host'} = $^a })
        .int( 'p', 'port',      { %!options{'port'} = $^a })
        .str( 's', 'server',    { $!server          = $^a })
        .parse(@args);

    if $version {
        my \CUDS := CompUnit::DependencySpecification;
        my $comp_unit = $*REPO.resolve( CUDS.new(:short-name($?PACKAGE.^name)) );
        my $version =
        try {
            CATCH {
                when X::AdHoc { .throw unless .payload ~~ /Distribution/; };
            }
            # This works for installed distributions, but not local via PERL6LIB, e.g.
            $comp_unit.distribution.meta<ver>;
        } // try {
            # This may work for loading the package via PERL6LIB
            Rakudo::Internals::JSON.from-json(
                $comp_unit.repo.prefix.parent.add('META6.json').slurp
            )<version>;
        }
        say "Crust version $version running under" if $version;
        say "perl6 version {$*PERL.compiler.version} built on {$*VM.name} version {$*VM.version}";
        exit 1;
    }

    while @args {
        given @args[0] {
            when '--' {
                @args.shift;
                @!args.append: @args;
                last;
            }
            when /^\-\-(<-[\=]>+)\=(.*)$/ {
                %!options{$/[0].Str} = $/[1].Str;
                @args.shift;
            }
            when /^\-\-(<-[\=]>+)$/ {
                @args.shift;
                my $key   = $/[0].Str;
                my $value = @args.shift;
                %!options{$key} = $value;
            }
            default {
                @!args.push: @args.shift;
            }
        }
    }

    for %!options.kv -> $k, $v {
        if $v ~~ /^<[0 .. 9]>+$/ {
            %!options{$k} = IntStr.new($v.Int, $v.Str);
        }
    }
}

method !setup() {
    CompUnit::RepositoryRegistry.use-repository(CompUnit::RepositoryRegistry.repository-for-spec($_))
        for @!inc;
    for @!modules {
        # FIXME: workaround for Bug RT #130535
        # ref: https://github.com/tokuhirom/p6-Crust/pull/86
        EVAL "use $_";
    }
}

method !locate-app() {
    if &!app {
        &!app
    } elsif $!eval {
        EVAL($!eval);
    } elsif @!args.elems > 0 {
        EVALFILE(@!args.shift)
    } else {
        EVALFILE('app.p6w')
    }
}

multi method run(&app) {
    &!app = &app;
    self.run();
}

multi method run() {
    self!setup();

    my &app = self!locate-app();

    if $!accesslog {
        require Crust::Middleware::AccessLog;
        &app = ::('Crust::Middleware::AccessLog').new(&app);
    }
    if $!lint {
        require Crust::Middleware::Lint;
        &app = ::('Crust::Middleware::Lint').new(&app);
    }

    my $handler = "Crust::Handler::{$!server}";
    # FIXME: workaround for Bug RT #130535
    # ref: https://github.com/tokuhirom/p6-Crust/pull/85
    EVAL "use $handler";
    my $httpd = ::($handler).new(|%!options);
    $httpd.run(&app);
}
