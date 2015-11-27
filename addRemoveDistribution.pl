#!/usr/bin/perl

sub printUsage {
  print("Usage: addRemoveRepository \e[4maction\e[0m \e[4mdistribution\e[0m\n\n");
  print("\e[4maction\e[0m must be \e[1menable\e[0m or \e[1mdisable\e[0m\n");
  print("\e[4mdistribution\e[0m must be \e[1mdefault\e[0m, \e[1msecurity\e[0m, \e[1mupdates\e[0m, \e[1mproposed\e[0m or \e[1mbackports\e[0m");
  exit(0);
}

sub parse {
  open(my $in, "sources.list") || die("Couldn't open '/etc/apt/sources.list': $!");

  while(<$in>) {
    chomp;
    if(/^deb(-src)? (.*).ubuntu.com\/ubuntu (.*?) (.*)/) {
      if($3 ne $distribution) {
        $4 =~ s/ #.*$//;
        if($1 eq "") {
          push(@entries, "$2,$4");
        }
        else {
          push(@srcEntries, "$2,$4");
        }
      }
      else {
        push(@discard, $_);
      }
    }
    push(@list, $_);
  }

  close($in);

  foreach my $x (@list) {
    ! grep(/^$x$/, @discard) && push(@diff, $x);
  }
}

sub rewrite {
  if($action eq "enable") {
    if(@discard > 0) {
      print("$distribution is enabled already. Aborting.\n");
      exit(1);
    }
    else {
      foreach(@diff) {
        print($_ . "\n");
      }
      foreach(@entries) {
        my @x = split(",");
        my @y = split(" ", $x[1]);
        $line = "deb $x[0].ubuntu.com/ubuntu $distribution @y #Added by addRemoveRepository";
        if(!grep(/^$line$/, @added)) {
          print($line . "\n");
          push(@added, $line);
        }
      }
      foreach(@srcEntries) {
        my @x = split(",");
        my @y = split(" ", $x[1]);
        $srcLine = "deb $x[0].ubuntu.com/ubuntu $distribution @y #Added by addRemoveRepository";
        if(!grep(/^$srcLine$/, @srcAdded)) {
          print($srcLine . "\n");
          push(@srcAdded, $srcLine);
        }
      }
    }
  }
  else {
    if(@discard == 0) {
      print("$distribution is disabled already. Aborting.\n");
      exit(1);
    }
    else {
      foreach(@diff) {
        print($_ . "\n");
      }
    }
  }
}

if(@ARGV == 2 && $ARGV[0] =~ /^(enable|disable)$/ && $ARGV[1] =~ /^(default|security|updates|proposed|backports)$/) {
  $action = $ARGV[0];
  $releaseCodename = `lsb_release -sc`;
  chomp($releaseCodename);
  if($ARGV[1] eq "default") {
    $distribution = $releaseCodename
  }
  else {
    $distribution = $releaseCodename . "-" . $ARGV[1];
  }
}
else {
  printUsage;
}

parse;
rewrite;

exit(0);
