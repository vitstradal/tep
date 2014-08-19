#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Encode qw(decode encode);

my @table;
my @max;
my $title;

my $latin2;

binmode STDIN, ':raw';
binmode STDOUT, ':utf8';

sub enc($)
{
  my ($txt) = @_;;
  if( $latin2 ) {
    $txt = decode("iso-8859-2", $txt);
  }

  utf8::decode($txt) if ! utf8::is_utf8($txt);

  return $txt;

}
my $idx = 0;
while (my $r = <> ) {
  utf8::decode($r);
  if( $r =~ m{<h1>(.*)</h1>} ) {
    $title = enc($1);
  }
  if( $r =~ m{<tr>} ) {
    push @table, [];
    $idx++;
  }
  next if $r =~ /<td.*mezera/;
  next if $r =~ /<td>\&nbsp</;
  if( $r =~ m{<td[^>]*>(.*)</td>} ) {
    my $val = enc($1);
    $val =~ s/&nbsp;?/ /g;
    $val =~ s/\t/ /g;
    $val =~ s/^  *//g;
    $val =~ s/  *$//g;
    $val =~ s/serie/série/i;
    #$val =~ s/v ročníku/V ročníku/i;
    #$val = lcfirst($val);
    $val = " $val " if $idx <= 1;

    my $len = length($val) ||0;
    push @{$table[-1]}, $val;
    my $pos = scalar(@{$table[-1]});
    $max[$pos-1] = $len   if ($max[$pos-1]||0)  < $len ;
  }
  $latin2 = 1 if( $r =~ /iso-8859-2/i );
}


print "= $title=\n\n";

my $th ='=';
for my $row (@table) {
  print "||";
  my $pos =0;
  for my $cell (@$row) {
    my $m = $max[$pos] || 1;
    #$m -= 2 if $th;
    #$cell =~ s/^ //g if $th;
    #$cell =~ s/ $//g if $th;
    printf "$th\%${m}s$th||", $cell;
    $pos++;
  }
  print "\n";
  $th =' ';
}

