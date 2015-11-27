#!/usr/bin/perl

sub printUsage {
  print("Usage: enableDisableDistribution \e[4maction\e[0m \e[4mdistribution\e[0m\n\n");
  print("\e[4maction\e[0m must be \e[1menable\e[0m or \e[1mdisable\e[0m\n");
  print("\e[4mdistribution\e[0m must be \e[1mdefault\e[0m, \e[1msecurity\e[0m, \e[1mupdates\e[0m, \e[1mproposed\e[0m or \e[1mbackports\e[0m");
  exit(0);
}

sub parse {
  open(my $in, "/etc/apt/sources.list") || die("Couldn't open '/etc/apt/sources.list': $!");

  while(<$in>) {
    my $pushList = 1; # sets to push the current element to the list to be printed regardless
    chomp; # removes a trailing newline if present
    if(/^deb(-src)? +(.*).ubuntu.com\/ubuntu +(.*?) +(.*?)( *$| +#.*)/) {
      my $src = $1 eq "-src"; # 0 if it's a binary repository, 1 if it's a source repository
      my $URI = $2;
      my @split = split("-", $3); # 1 element if it's a "default" distribution, 2 elements if it's not a "default" distribution
      my $components = $4;
      $components =~ s/ {2,}//; # removes consecutive spaces if present
      if(($distribution eq "default" && defined($split[1])) || ($distribution ne "default" && $split[1] ne $distribution)) { # scrapes the data for the entry to be builded
        if(! $src) { # pushes to the binary entries to be builded
          push(@entries, "$URI,$split[0],$components");
        }
        else { # pushes to the source entries to be builded
          push(@srcEntries, "$URI,$split[0],$components");
        }
      }
      else {
        $pushList = 0; # sets to push the current element to the list to be discarded in case the distribution has to be disabled
      }
    }
    if($pushList) {
      push(@list, $_); # pushes the current element to the list to be printed regardless (the trailing newline has been chomp()ed)
    }
    else {
      push(@discard, $_); # pushes the current element to the list to be discarded in case the distribution has to be disabled (the trailing newline has been chomp()ed)
    }
  }

  close($in);
}

sub rewrite {
  if($action eq "enable") { # prints the list of entries to be printed regardless and builds and prints the new entries or exits if entries for the distribution have been found
    if(@discard > 0) { # entries for the distribution have been found; exits
      print("$distribution is enabled already. Aborting.\n");
      exit(1);
    }
    else { # entries for the distribution haven't been found; prints the list of entries to be printed regardless
      open(my $out, ">", "/etc/apt/sources.list") || die("Couldn't open '/etc/apt/sources.list': $!");

      foreach(@list) {
        print $out ($_ . "\n");
      }
      foreach(@entries) { # builds and prints the new entries for binary repositories
        my $line;
        my @x = split(",");
        my @y = split(" ", $x[2]);
        if($distribution ne "default") {
          $line = "deb $x[0].ubuntu.com/ubuntu $x[1]-$distribution @y";
        }
        else {
          $line = "deb $x[0].ubuntu.com/ubuntu $x[1] @y";
        }
        if(! grep(/^$line$/, @diff)) {
          print $out ($line . " #Added by enableDisableDistribution\n");
          push(@diff, $line);
        }
      }
      foreach(@srcEntries) { # builds and prints the new entries for source repositories
        my $srcLine;
        my @x = split(",");
        my @y = split(" ", $x[2]);
        if($distribution ne "default") {
          $srcLine = "deb-src $x[0].ubuntu.com/ubuntu $x[1]-$distribution @y";
        }
        else {
          $srcLine = "deb-src $x[0].ubuntu.com/ubuntu $x[1] @y";
        }
        if(! grep(/^$srcLine$/, @diff)) {
          print $out ($srcLine . " #Added by enableDisableDistribution\n");
          push(@diff, $srcLine);
        }
      }

      close($out);
    }
  }
  else { # prints the list of entries to be printed regardless discarding the entries to be discarded or exits if entries for the distribution haven't been found
    if(@discard == 0) { # entries for the distribution haven't been found; exits
      print("$distribution is disabled already. Aborting.\n");
      exit(1);
    }
    else { # entries for the distribution have been found; prints the list of entries to be printed regardless discarding the entries to be discarded
      open(my $out, ">", "/etc/apt/sources.list") || die("Couldn't open '/etc/apt/sources.list': $!");

      foreach my $line (@list) {
        ! grep(/^$line$/, @discard) && print $out ($line . "\n");
      }

      close($out);
    }
  }
}

if($> != 0) {
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
