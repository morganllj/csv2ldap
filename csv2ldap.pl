#!/usr/bin/perl -w
#
# morgan@morganjones.org
# import a csv file into ldap--used to bulk add users from a csv.
# Not the most straightforward to use and needs to be generalized but got the job done.

# $ perl -pi -e 's/\r/\n/g' Morgan_Charter_Import.csv
# $ ~/Docs/git/ldap_utils/import_from_csv.pl < ~morgan/Desktop/Morgan_Charter_Import.csv |ldapmodify -a -x -H ldaps://devldapm01.domain.org -y pass

# to delete if applicable:
# $ ldapsearch -LLL -x  -y ~/Docs/.pass -H ldaps://devldapm01.domain.org orgaccountstatuslog="*for Compass*" dn| sed 's/dn: //' | ldapdelete  -v  -D uid=morgan,ou=employees,dc=domain,dc=org -y ~/Docs/.pass -H ldaps://devldapm01.domain.org
#
# for i in `./import_from_csv.pl ~/Desktop/Morgan_Charter_Import.csv 2>&1 | grep skipping|sed 's/skipping //'|sed 's/\.\.\.//'`; do echo $i ; echo; done|ldapdelete -H ldaps://devldapm01.domain.net -D uid=morgan,ou=employees,dc=domain,dc=org -v -y ~/Docs/.pass 


use strict;

my @fields = qw/orgeidn uid userpassword cn givenname sn orgmiddlename orgsuffix orghomeorgcd orghomeorg orgsponsorhomeorgcd orgsponsorhomeorg orgsponsoreidn orgvendorname mail orgworktelephonedid orgassociateusertypecd orgassociateusertype orgstateid sambasid/;

my @common_fields = qw/objectClass inetorgperson objectClass ntUser objectClass orgAssociate objectClass top objectClass sambaSamAccount objectClass organizationalPerson objectClass person objectClass inetuser orgaccountstatus active orgaccountactive TRUE/;

#push @common_fields, ("orgAccountStatusLog", "201508170000000Z; 0000060473-kacless imported user for Compass from Oracle External Users");

my $i=0;
while (<>) {
    next if ($i++ < 1);

    my @field_values = split /,/;

    next if ($field_values[0] eq "orgEIDN");

    my $empid = $field_values[0];
    next unless ($empid);

    my $entry = `ldapsearch -D uid=morgan,ou=employees,dc=domain,dc=org -x -w 'pass' -H ldaps://ldapm01.domain.net -LLLb dc=domain,dc=org orgeidn=$empid dn objectclass`;
    
    my $dn = $1
        if ($entry =~ /dn:\s*([^\n]+)\n/);

    if (defined $dn) {
	print STDERR "skipping $dn...\n";
	next;
    }

    my $dn2add = "uid=" . $field_values[1] . ",ou=employees,dc=domain,dc=org";

    print "dn: $dn2add\n";

    my $h = 0;
    for (@common_fields) {
	if (!($h % 2)) {
	    print $common_fields[$h];
	} else {
	    print ": ", $common_fields[$h], "\n";
	}
	$h++;
    }
      

    my $i = 0;
    for (@fields) {
	chomp $field_values[$i];
	print $fields[$i] , ": " , $field_values[$i] . "\n";
	$i++;
    }
    print "ntuserdomainid: $field_values[1]\n";
    print "orgaccountstatuslog: 20160220000000Z 9000000015-morgan created from ldif for kacless\n";
    print "\n";
}
