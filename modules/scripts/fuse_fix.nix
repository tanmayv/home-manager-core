{ pkgs, lib, ... }:

let
  fuse_fix = pkgs.writeScriptBin "fuse_fix" ''
    #!/usr/bin/env perl
    use strict;
    use warnings;
    use Getopt::Long;
    my $ENOTCONN = 107;
    my %errors;

    my $opt_verbose;
    GetOptions( "verbose!" => \$opt_verbose );

    for my $file ( glob '/proc/[0-9]*/cwd' ) {
      opendir( my $D, $file );
      my ($pid) = $file =~ m!/proc/(\d+)/!;
      if ( $! == $ENOTCONN ) {
        open my $F, "-|", <<EOSYSTEM;
    gdb /proc/$pid/exe $pid <<'EOF' 2>&1
    call (char*)getenv("PWD")
    call (int)chdir(\$1)
    if \$2 == 0
      printf "SUCCESS\\n"
    else
      call errno
      call (char*)strerror(\$3)
      printf "Error %d '%s'\\n", \$3, \$4
    end
    EOF
    EOSYSTEM
        my $response = 0;
        while(<$F>) {
          print if $opt_verbose;
          if(/SUCCESS/) {
            print "Fixed pid $pid\n";
            $response = 1;
          }
          if(/Error (-?\d+) \'(.*)\'/) {
            print "Error in chdir pid $pid errno $1: $2\n";
            $response = 1;
          }
        }
        if(!$response) {
          print "No response from gdb pid $pid\n";
        }
        push @{ $errors{OK} }, $pid;
      } elsif ( $! == 0 ) {
        closedir $D;
      } else {
        push @{ $errors{$!} }, $pid;
      }
    }

    if ($opt_verbose) {
      for my $i ( sort keys %errors ) {
        print "$i @{$errors{$i}}\n";
      }
    }
  '';
in
{
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.packages = [
      fuse_fix
      pkgs.gdb # The script requires gdb
    ];
  };
}
