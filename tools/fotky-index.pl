#!/usr/bin/perl

use File::Slurp;
use File::Copy;
use File::Find;
use Data::Dump 'pp';
use YAML::Syck;

use strict;
use warnings;
use utf8;

my ($wiki_file, $fotoroot, $path) = @ARGV;

sub escy($)
{
  my ($t) = @_;;
  utf8::decode($t) if ! utf8::is_utf8($t);
  return Dump($t) =~ s/\n$//r;
}

$YAML::Syck::Headless = 1;

sub proces($$)
{
  my ($y, $fotoroot) = @_;;

  my $fullpath = $fotoroot;
  my @jpgs;
  File::Find::find({ wanted=>sub { push(@jpgs, $_ =~ s/^\Q$fotoroot\E//r)  if /-v\.jpe?g/i }, no_chdir=> 1}, $fullpath);

  utf8::decode($y) if ! utf8::is_utf8($y);
  my $h = Load($y);

  $h = {} if ref $h ne 'HASH';

  $h = { title => $h->{title} || "TODO:Název galerie!",
         path =>  $h->{path} ||  "data/cesta/k/fotkam/relativne/k/home/www/html",
         data =>  $h->{data} || [],
         cats =>  $h->{cats} || { org => 'Orgove' },
       };

  my %jmap = (map {$_=>1} @jpgs);

  # my own dump;
  my $data = '';
  $data .= "title: @{[escy($h->{title})]}\n";
  $data .= "path: @{[escy($h->{path})]}\n";
  $data .= "cats: \n";
  $data .= "   @{[escy($_)]}: @{[escy($h->{cats}->{$_})]}\n" for( keys %{$h->{cats}});
  $data .= "data:\n";

  for my $item (@{$h->{data}}) {
    my $ff = $item->{foto};
    $data .= "- desc: @{[escy($item->{desc})]}\n";
    $data .= "  foto: @{[escy($item->{foto})]}\n";
    $data .= "  cats: [" . join (',', map {escy($_)} @{$item->{cats}}) . "]\n";
    #print "FOTO:$ff:valid:", utf8::valid($ff) ? 1 : 0,"iu:", utf8::is_utf8($ff) ? 1 : 0, "\n";
    warn "warning: $ff not on disk\n"  if ! $jmap{$ff};
    delete $jmap{$ff};
  }
  for my $f (sort keys %jmap) {
    my $desc = ($f =~ s!^.*/|\.jpe?g$!!gir);
    $data .= "- desc: @{[escy($desc)]}\n";
    $data .= "  foto: @{[escy($f)]}\n";
    $data .= "  cats: [ ]\n";
  }
  return "{{fotky\n$data\n}}";
}

$fotoroot ||= '/home/www/html';
$path ||= '';

die "usage: $0 file.wiki [ /path/to/foto/root [ rel/path/to/galery ] ] \n" if ! $wiki_file ;
my $wiki;

if( -f $wiki_file )  {
   copy($wiki_file, "$wiki_file.backup") or die "cannt create backup";
   $wiki = read_file($wiki_file, binmode => ':utf8') or die;

} else {
   $wiki = "{{fotky\n---\n path: \"$path\"\n}}\n";
}

$wiki =~ s/\{\{fotky\b(.*)^\}\}/proces($1,$fotoroot)/gsem;
write_file($wiki_file, $wiki) or die "cannt write to $wiki_file";

