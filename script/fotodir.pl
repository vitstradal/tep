#!/usr/bin/env perl

use utf8;

my $dir = shift @ARGV;

die "usage: $0 balbal/fotky/dir" unless $dir;

opendir DIR, $dir or die "no such dir '$dir'";

print <<EOF;
{{foto
title: Fotky z akce
path: /fotky/tabor/2014
cats:
   an: Anička
data:
EOF

for my $a ( readdir DIR) {
  next if $a =~ /^\./;
  print <<EOF;
  - desc:
    foto: $a
    cats: [ ]
EOF
}

print "\n}}\n";

