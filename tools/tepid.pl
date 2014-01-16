#!/usr/bin/perl

use utf8;
use strict;
use warnings;

my %res;

open(TEP, $ARGV[0]) or die;
open(PIK, $ARGV[1]) or die;
open(IN, $ARGV[2]) or die;
while(my $r = <TEP>) {
  chomp $r;
  my ($id, $last, $name) =  split(/;/, $r);
  print STDERR "double tep $last-$name\n" if defined $res{"$last-$name"}->{tepid};
  $res{"$last-$name"}->{tepid} = $id;
  $res{"$last-$name"}->{last} = $last;
  $res{"$last-$name"}->{name} = $name;
} 

while(my $r = <PIK>) {
  chomp $r;
  next if $r =~ /^["%]/;
  my ($id, $last, $name) =  split(/;/, $r);
  print STDERR "double pik $last-$name\n" if defined $res{"$last-$name"}->{pikid};
  $res{"$last-$name"}->{pikid} = $id;
  $res{"$last-$name"}->{last} = $last;
  $res{"$last-$name"}->{name} = $name;
} 

for my $k (sort keys %res) {
  my $v = $res{$k};
  print STDERR "not in pik: $v->{last};$v->{name}\n" if ! $v->{pikid};
  print STDERR "not in tep: $v->{last};$v->{name}\n" if ! $v->{tepid};
}


while(my $r = <IN> ) { 
  chomp ($r);
  if ($r =~ /^[%"]/ ) {
  	print "$r\n";
	next;
  }

  if ($r =~ /(^|;)(\d\d\d);([ \w]*)([ ;])([\w]* ?)($|;)/ ) {

    my ($prefix, $pikid, $last, $sep, $name, $tail) = ("$`$1", $2, $3, $4, $5, "$6$'");
    if( defined( my $solver =  $res{"$last-$name"})) {
       my $id = sprintf "%03s", ($solver->{tepid} || "XXX");
       print "$prefix$id;$last$sep$name$tail\n";
    } else {
     print STDERR "no solver: $r\n"
    }
  }
}

