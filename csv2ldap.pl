#!/usr/bin/perl -w
#
# morgan@morganjones.org
# import a csv file into ldap--used to bulk add users from a csv.
# only has basic functionality, needs to be expanded

use strict;
use Net::LDAP;
use Getopt::Std;
use Data::Dumper;

$|=1;

my %opts;
getopts('nf:c:b:y:H:D:s', \%opts);

print "-n used, no changes will be made\n"
  if (exists $opts{n});

exists $opts{H} || printUsage();
exists $opts{b} || printUsage();
exists $opts{r} && printUsage();

my $ldap = Net::LDAP->new($opts{H}) or die "$@";

my $pfh;
open ($pfh, $opts{y});
my $pass = <$pfh>;
close $pass;

$ldap->bind($opts{D}, password=>$pass);

my @fields;
if (exists $opts{f}) {
    @fields = split (/,/, $opts{f});
}

my $indexattr = shift @fields;

my $csvfh;

open ($csvfh, $opts{c}) || die "can't open $opts{c}";

# ignore the header if so requested
<$csvfh> if (exists $opts{s});

while (<$csvfh>) {
    my @values = split /,/;
    my $indexvalue = shift @values;
    my $filter = "(" . ${indexattr} . "=" . ${indexvalue} . ")";
    print "\n$filter\n";
    
    my $rslt = $ldap->search(base=>$opts{b}, filter=>$filter);
    $rslt->code && warn "problem searching: " . $rslt->error;

    my $entry = $rslt->as_struct();

    my @DNs = keys %$entry;
    if ($#DNs!=0) {
	warn "$filter didn't return exactly one entry, ignoring";
	next;
    }

    my $dn = $DNs[0];
    
    my $i=0;
    while (my $v = shift @values) {
	my $a = $fields[$i++];

	if (exists $entry->{$dn}{lc $a}) {
	    print "Skipping $dn, it already contains $a: @{$entry->{$dn}{lc $a}}\n";
	    next;
	}

	chomp $v;
	print "adding $a $v to $dn\n";

	if (!exists $opts{n}) {
	    my $mod_rslt = $ldap->modify($dn, add => { $a => $v });
	    $mod_rslt->code && die "problem modifying: " . $mod_rslt->error
	      if (!exists $opts{k});
	    $mod_rslt->code && warn "problem modifying: " . $mod_rslt->error;
	}
				  
    }
}

sub printUsage {
    print "usage: $0 [-n] [-k] [-s] [ -m | -a] -H ldapurl -D binddn -b basedn -y passfile [ -f indexfield,field1,field2,... | -r ] -c csv\n";
    print "\t-n just print, don't make changes\n";
    print "\t-k just warn, don't exit on errors\n";
    print "\t-s skip header in csv file\n";
    print "\t-r read header to identify attr name\n";
    print "\t-f list attrs on the command line\n";
    print "\n";
    print "\t-r and -f are mutually exclusive\n";
    print "\t\t-r is not yet implemented\n";
    print "\t-m and -a are mutually exclusive\n";
    print "\t-m currently only adds, it will print an error if the attr exists in the entry\n";

    exit 0;
}
