#!/usr/bin/perl

use utf8;
use strict;
use warnings;
die "useage: $0 lidi.tep lidi.pik data.in" unless @ARGV;

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

my %res;

open(TEP, '<:utf8', $ARGV[0]) or die;
open(PIK, '<:utf8', $ARGV[1]) or die;
while(my $r = <TEP>) {
  chomp $r;
  my ($id, $last, $name) =  split(/;/, $r);
  $id = sprintf('%03s', $id);
  if( my $dtepid =  defined $res{"$last $name"}->{tepid} ) {
    print STDERR "!!! double in tep $last $name ($dtepid vs. $id)\n";
  }

  $res{"$last $name"}->{tepid} = $id;
  $res{"$last $name"}->{last} = $last;
  $res{"$last $name"}->{name} = $name;
} 

my $wrong = 0;
my $show_wrong = 0;
#$show_wrong = 1;
while(my $r = <PIK>) {
  chomp $r;
  next if $r =~ /^["%]/;
  next if $r =~ /^\s*$/;
  my ($id, $last, $name) =  split(/;/, $r);
  print STDERR "double pik $last $name\n" if defined $res{"$last $name"}->{pikid};
  $res{"$last $name"}->{pikid} = $id;
  my $tepid = $res{"$last $name"}->{tepid};
  if(!defined($tepid) ||  $id ne $tepid) {
    $wrong++;
    print STDERR "+++ wrong id: $last $name(pik:$id tep:",($tepid||'nul'), ")\n" if $show_wrong;
  }
  $res{"$last $name"}->{pikid} = $id;
  $res{"$last $name"}->{last} = $last;
  $res{"$last $name"}->{name} = $name;
} 

for my $k (sort keys %res) {
  my $v = $res{$k};
  print STDERR "+++ not in pik: $v->{last};$v->{name}\n" if ! $v->{pikid};
  print STDERR "--- not in tep: $v->{last};$v->{name}\n" if ! $v->{tepid};
}

print STDERR "--- wrong ids: $wrong\n" if $wrong;

exit unless defined $ARGV[2];

open(IN, '<:utf8', $ARGV[2]) or die;
while(my $r = <IN> ) { 
  chomp ($r);
  if ($r =~ /^[%"]|^\s*$/ ) {
  	print "$r\n";
	next;
  }

  if ($r =~ /^(\d\d\d);([ \w]*);([ \w]*);/ ) {

    my ($id, $last, $name, $tail) = ($1, $2, $3, $');
    if( defined( my $solver =  $res{"$last $name"})) {
       my $id = ($solver->{tepid} || "XXX");
       print "$id;$last;$name;$tail\n";
    } else {
     print STDERR "no solver: $r\n"
    }
  }
  elsif ($r =~ /^(\d\d\d);([ \w]*?)\s*;/ ) {
    my ($pref, $id, $last_name, $tail) = ($1, $2, $3, $');
    if( defined( my $solver =  $res{"$last_name"})) {
       my $id = ($solver->{tepid} || "XXX");
       print "$id;$last_name;$tail\n";
    } else {
     print STDERR "no solver: $r ($last_name)\n"
    }
  } else {
     print STDERR "not understand line: '$r'\n";
  }
}

