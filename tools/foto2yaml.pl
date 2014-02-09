#!/usr/bin/perl
use strict;
use warnings;

my ($file, $path) =  @ARGV;
my %y = ();
open F, '<', "$file" or die "cannt open $file";

while(my $r = <F>) {
  chomp($r);
  next if $r =~ /^\s*$/;
  my ($src, $desc, $cats) = split(m{\|}, $r);
  $desc =~ s/!$/! /;
  $desc = "\"$desc\""  if $desc =~ /[:]|^\?$/;
  if( !$src && ( !$cats || $cats =~ /^-\.$/ ) ) {
    $y{title} = $desc;
  }
  elsif( !$src ) {
    $y{cats}->{$cats} = $desc;
  }
  else {
    $cats =~ s/\s*//g;
    my @cats_arr = split(m{\.}, $cats);
    push(@{$y{data}}, {foto=> $src, desc=>$desc, cats=> \@cats_arr});
  }
}

print "{{foto\n";
print "title: $y{title}\n" if $y{title};
print "path: $path\n";
if( $y{cats} ) {
  print "cats:\n";
  for my $c (sort keys %{$y{cats}}) {
    print "   $c: $y{cats}->{$c}\n"
  }
  print "\n";
}
print "data:\n";
for my $d (@{$y{data}}) {
  print " - desc: $d->{desc}\n";
  print "   foto: $d->{foto}\n";
  print "   cats: [ ",  join(', ', map {$_ eq '-' ? '"-"' : $_ } @{$d->{cats}}),  " ]\n";
  #print "\n";
}
print "}}\n";
