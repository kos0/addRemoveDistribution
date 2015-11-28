#!/usr/bin/perl

sub printUsage {
    print("Usage: enableDisableDistribution \e[4maction\e[0m \e[4mdistribution\e[0m\n\n");
    print("\e[4maction\e[0m must be \e[1menable\e[0m or \e[1mdisable\e[0m\n");
    print("\e[4mdistribution\e[0m must be \e[1mdefault\e[0m, \e[1msecurity\e[0m, \e[1mupdates\e[0m, \e[1mproposed\e[0m or \e[1mbackports\e[0m");
    exit(0);
}

sub parse {
    open(my $in, "sources.list") || die("Couldn't open '/etc/apt/sources.list': $!");
    while(<$in>) {
        my $matchDistribution;
        chomp;
        if(/^deb(-src)? +(.*?).ubuntu.com\/ubuntu\/? +(.*?) +(.*?) *(#.*)?$/) {
            my $debSrc = $1 eq "-src";
            my $URI = $2;
            my @split = split("-", $3);
            my @components = sort(split(" ", $4));
            if(($distribution eq "default" && defined($split[1])) || ($distribution ne "default" && $split[1] ne $distribution)) {
                (! $debSrc && push(@add, "$URI,$split[0],@components")) || push(@addSrc, "$URI,$split[0],@components");
            }
            else {
                $matchDistribution = 1;
            }
        }
        (! $matchDistribution && push(@notMatchDistribution, $_)) || push(@matchDistribution, $_);
    }
    close($in);
}

sub rewrite {
    if($action eq "enable") {
        if(@matchDistribution == 0) {
            open(my $out, "| cat") || die("Couldn't open '/etc/apt/sources.list': $!");
            foreach(@notMatchDistribution) {
                print $out ($_ . "\n");
            }
            foreach(@add) {
                my @x = split(",");
                my @y = split(" ", $x[2]);
                my $line = sprintf("deb $x[0].ubuntu.com/ubuntu $x[1]%s @y", $distribution ne "default" && sprintf("-$distribution"));
                if(! grep(/^$line$/, @added)) {
                    print $out ($line . " #Added by enableDisableDistribution\n");
                    push(@added, $line);
                }
            }
            foreach(@addSrc) {
                my @x = split(",");
                my @y = split(" ", $x[2]);
                my $srcLine = sprintf("deb-src $x[0].ubuntu.com/ubuntu $x[1]%s @y", $distribution ne "default" && sprintf("-$distribution"));
                if(! grep(/^$srcLine$/, @addedSrc)) {
                    print $out ($srcLine . " #Added by enableDisableDistribution\n");
                    push(@addedSrc, $srcLine);
                }
            }
            close($out);
        }
        else {
            print("$distribution is enabled already. Aborting.\n");
            exit(1);
        }
    }
    else {
        if(@matchDistribution > 0) {
            open(my $out, "| cat") || die("Couldn't open '/etc/apt/sources.list': $!");
            foreach my $line (@notMatchDistribution) {
                ! grep(/^$line$/, @matchDistribution) && print $out ($line . "\n");
            }
            close($out);
        }
        else {
            print("$distribution is disabled already. Aborting.\n");
            exit(1);
        }
    }
}

if($> == 0) {
    print("You must be root to run enableDisableDistribution.\n");
    exit(1);
}
if(@ARGV == 2 && $ARGV[0] =~ /^(enable|disable)$/ && $ARGV[1] =~ /^(default|security|updates|proposed|backports)$/) {
    $action = $ARGV[0];
    $distribution = $ARGV[1];
}
else {
    printUsage;
}

parse;
rewrite;

exit(0);
