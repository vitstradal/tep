#!/usr/bin/perl

use File::Slurp;
use File::Copy;
use Cwd;
use File::Find;
use Getopt::Long;
use Data::Dump 'pp';
use YAML::Syck;

use strict;
use warnings;
use utf8;

my $webroot = '/home/www/html';
my $fotodir = getcwd;
my $wiki_file;
my $wikuk_file = '/home/pikomat/wikuk/foto.wiki';
my $wikuk =  0;
my $update  = 0;
my $help =0;

sub escy($)
{
  my ($t) = @_;;
  utf8::decode($t) if ! utf8::is_utf8($t);
  return Dump($t) =~ s/\n$//r;
}

$YAML::Syck::Headless = 1;

sub proces($$)
{
  my ($y, $fotodir) = @_;;

  my $fullpath = $fotodir;
  my @jpgs;
  File::Find::find({ wanted=>sub { push(@jpgs, $_ =~ s/^\Q$fotodir\E//r)  if /-v\.jpe?g/i }, no_chdir=> 1}, $fullpath);

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
  return "{{foto\n$data\n}}";
}

sub usage 
{
   die <<EOL
usage: $0  [ -w /path/to/www/root ] [ -d /abs/path/to/to/galery ] [-u] output.wiki 
   -o output (default: $wiki_file)
   -w web root (default: $webroot)
   -d dir (default: $fotodir)
   -u update file existing
   -k short for -o $wikuk_file,
   -h this help
EOL
}


GetOptions(
        'w|webroot=s'   => \$webroot,
        'd|foto-dir=s'  => \$fotodir,
        'o|output=s'    => \$wiki_file,
        'u|update'      => \$update,
        'k|wikuk'       => \$wikuk,
        'h|help'        => \$help,
);

$wiki_file = $wikuk_file if $wikuk;

usage() if ! $wiki_file ;
usage() if $help;

my $wiki;

my $foto_dir_rel = $fotodir =~ s{^\Q$webroot\E/*}{}r;
$foto_dir_rel =~ s{^fotky/}{data/};

if( $update && -f $wiki_file  )  {
   copy($wiki_file, "$wiki_file.backup") or die "cannt create backup";
   $wiki = read_file($wiki_file, binmode => ':utf8') or die;

} else {
   $wiki = "{{foto\n---\n path: \"/$foto_dir_rel\"\n}}\n";
}

$wiki =~ s/\{\{foto\b(.*)^\}\}/proces($1,$fotodir)/gsem;
write_file($wiki_file, $wiki) or die "cannt write to $wiki_file";
print STDERR "$wiki_file done\n";

