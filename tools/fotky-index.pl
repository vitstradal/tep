#!/usr/bin/perl

use feature 'say';
use File::Slurp;
use File::Copy;
use Cwd;
use File::Find;
use Getopt::Long;
use Data::Dump 'pp';
use YAML::Syck;
use Function::Parameters;
use IPC::Run qw(run);
use Path::Tiny;

use strict;
use warnings;
use utf8;

my $webroot = '/home/www/html';
my $foto_dir = getcwd;
my $wiki_file;
my $WIKUK_FILE = '/home/pikomat/wikuk/foto.wiki';
my $wikuk =  0;
my $want_update  = 0;
my $help =0;
my $test =0;
my $do_index =0;
my $do_thumnails =0;

fun escy($t)
{
  utf8::decode($t) if ! utf8::is_utf8($t);
  return Dump($t) =~ s/\n$//r;
}

$YAML::Syck::Headless = 1;

fun convert($filename_base, $size ) {
        my $geometry =  $size eq 'n'
                ? '840x840'
                : '300x300';

        my $filename_v = "$filename_base-v.jpg";
        my $filename_size = "$filename_base-$size.jpg";

        if( ! -f $filename_v ) {
                say "$filename_v not found";
                return;
        }
        if( -f $filename_size && path($filename_v)->stat->mtime < path($filename_size)->stat->mtime ) {
                say "$filename_size skip ";
                return;
        }

        my @cmd = ( 'convert', $filename_v, '-auto-orient',  -geometry => $geometry, $filename_size);
        say pp(\@cmd);
        run(\@cmd);
}

fun convert_n_m($filename) {
        my $filename_base = $filename =~ s/\.jpe?g$//ri;
        return if $filename_base =~ /-[mn]$/;

        if( $filename_base !~ /-v$/ ) {
                say "moving $filename -> $filename_base-v.jpg";
                path($filename)->move("$filename_base-v.jpg");
        }
        $filename_base =~ s/-v//;
        say "$filename_base";
        convert($filename_base, 'n');
        convert($filename_base, 'm');
}

fun thumnails($foto_dir) {
        my @jpgs;
        File::Find::find(
                {
                        wanted=>sub {
                                push(@jpgs, $_ ) if /\.jpe?g$/i;
                        },
                        no_chdir=> 1
                },
                $foto_dir
        );
        for my $jpg (@jpgs) {
                convert_n_m($jpg);
        }
}

fun update_foto($yaml_data, $foto_dir) {
        my $fullpath = $foto_dir;
        my @jpgs;
        File::Find::find({ wanted=>sub { push(@jpgs, $_ =~ s/^\Q$foto_dir\E//r)  if /-v\.jpe?g/i }, no_chdir=> 1}, $fullpath);

        utf8::decode($yaml_data) if ! utf8::is_utf8($yaml_data);
        my $h = Load($yaml_data);

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

fun usage()
{
        die <<EOL
usage: $0  [ -w /path/to/www/root ] [ -d /abs/path/to/to/galery ] [-u] output.wiki 
        -o output (default: $wiki_file)
        -w web root (default: $webroot)
        -d dir (default: $foto_dir)
        -u update file existing
        -k short for -o $WIKUK_FILE,
        -h this help
EOL
}



fun update_or_create_foto_index($foto_dir, $wiki_file, $want_update) {

        my $foto_dir_rel = $foto_dir =~ s{^\Q$webroot\E/*}{}r;
        $foto_dir_rel =~ s{^fotky/}{data/};

        my $wiki_text;

        if( $want_update && -f $wiki_file  )  {
                copy($wiki_file, "$wiki_file.backup") or die "cannt create backup";
                $wiki_text = read_file($wiki_file, binmode => ':utf8') or die;

        } else {
                $wiki_text = "{{foto\n---\n path: \"/$foto_dir_rel\"\n}}\n";
        }

        $wiki_text =~ s/\{\{foto\b(.*)^\}\}/update_foto($1,$foto_dir)/gsem;
        write_file($wiki_file, $wiki_text) or die "cannt write to $wiki_file";
}

##########################################################
# main
fun main() {
        GetOptions(
                'w|webroot=s'   => \$webroot,
                'i|index'       => \$do_index,
                't|thumnails'   => \$do_thumnails,
                'd|foto-dir=s'  => \$foto_dir,
                'o|output=s'    => \$wiki_file,
                'u|update'      => \$want_update,
                'k|wikuk'       => \$wikuk,
                'h|help'        => \$help,
                'test'          => \$test,
        );

        $wiki_file = $WIKUK_FILE if $wikuk;
        $wiki_file = "$foto_dir/foto.wiki" unless $wiki_file;

        usage() if ! $wiki_file ;
        usage() if $help;

        if( $test ) {
                die "argv:". pp(\@ARGV);
        }

        if( $do_index ) {
                update_or_create_foto_index( $foto_dir, $wiki_file, $want_update);
                print STDERR "$wiki_file done\n";
        }

        if( $do_thumnails ) {
                thumnails($foto_dir);
        }
}

main();
