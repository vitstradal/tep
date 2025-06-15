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

my $WIKUK_FILE = '/home/pikomat/wikuk/foto.wiki';
my $HLUBINA_ROOT_DIR = '/home/www/sklep-hlubina/fotky';
my $HTML_DATA_DIR = '/home/www/html/data';

my $webroot = '/home/www/html';
my $foto_dir = getcwd;
my $wiki_file;
my $do_wikuk =  0;
my $want_update  = 0;
my $help =0;
my $verbose =0;
my $test =0;
my $do_index =0;
my $do_thumnails =0;
my $move_from_dir;
my $wiki_suffix;
my $do_readme;
my $hlubina_file;


fun escy($t)
{
  utf8::decode($t) if ! utf8::is_utf8($t);
  return Dump($t) =~ s/\n$//r;
}

$YAML::Syck::Headless = 1;

fun convert($filename_base, $size, $verbose ) {
        my $geometry =  $size eq 'n'
                ? '840x840'
                : '300x300';

        my $filename_v = "$filename_base-v.jpg";
        my $filename_size = "$filename_base-$size.jpg";

        if( ! -f $filename_v ) {
                say "$filename_v: not found";
                return;
        }
        if( -f $filename_size && path($filename_v)->stat->mtime < path($filename_size)->stat->mtime ) {
                say "$filename_size: skip" if $verbose;
                return;
        }
        my @cmd = ( 'convert', $filename_v, '-auto-orient',  -geometry => $geometry, $filename_size);
        say "$filename_size: created from $filename_size" if $verbose ;
        run(\@cmd);
}

fun convert_n_m($filename, $verbose) {
        my $filename_base = $filename =~ s/\.jpe?g$//ri;
        return if $filename_base =~ /-[mn]$/;

        my $filename_v = "$filename_base-v.jpg";
        if( $filename_base !~ /-v$/ ) {
                say "$filename_v: created from $filename";
                path($filename)->move($filename_v);
        }
        $filename_base =~ s/-v//;
        #say "$filename_base.jpg: " if $verbose;
        convert($filename_base, 'n', $verbose);
        convert($filename_base, 'm', $verbose);
}

fun do_readme($move_from_dir, $wiki_file, $verbose) {
        my $readme_file = path($move_from_dir)->child('README.md');
        my $wiki_url = $wiki_file =~ s{/home/pikomat/}{https://pikomat.mff.cuni.cz/}r;
        my $readme_txt = <<EOL;
# Foto dir

* Upload to this dir, and run action 'Foto Index'
* Results are:  [here]($wiki_url)
* Edit are:  [here]($wiki_url?edit=me)

EOL
        $readme_file->spew_utf8($readme_txt);
        say "$readme_file: done" if $verbose;
}

fun do_move_from_dir($move_from_dir, $move_to_dir, $vebose) {
        my @jpgs;
        File::Find::find(
                {
                        wanted=>sub {
                                my $relative = File::Spec->abs2rel($File::Find::name, $move_from_dir);
                                push(@jpgs, $relative ) if /\.jpe?g$/i;
                        },
                        no_chdir=> 1
                },
                $move_from_dir
        );
        for my $jpg ( @jpgs ) {
                my $jpg_src = path(File::Spec->catfile($move_from_dir, $jpg));
                my $jpg_dst = path(File::Spec->catfile($move_to_dir, $jpg));
                if( ! -e $jpg_dst || -s $jpg_dst != -s $jpg_src ||  path($jpg_src)->stat->mtime != path($jpg_dst)->stat->mtime ) {
                        path($jpg_dst)->parent->mkpath;
                        $jpg_src->move($jpg_dst);
                        say "$jpg_src: moved to $jpg_dst" if $verbose;
                }
                else {
                        say "$jpg_src: skipped" if $verbose;
                }
        }
        #say "jpgs: $_" for(@jpgs);
}

fun make_dir_for($file) {
        path($file)->parent->mkpath
}

fun do_thumnails($foto_dir, $verbose) {
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
                convert_n_m($jpg, $verbose);
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
usage: $0  [-i,--index | -t,--thumnails ] [ -w /path/to/www/root ] [ -d /abs/path/to/to/galery ] [-u] output.wiki 

        -t --thumnails create image-v.jpg image-n.jpg image-m.jpg
        -i --index create foto.wiki
        -m --move-from DIR
        -r --readme leave README in move-from-dir
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
                'm|move-from=s'   => \$move_from_dir,
                't|thumnails'   => \$do_thumnails,
                'd|foto-dir=s'  => \$foto_dir,
                'o|output=s'    => \$wiki_file,
                'u|update'      => \$want_update,
                'k|wikuk'       => \$do_wikuk,
                'h|help'        => \$help,
                'v|verbose'     => \$verbose,
                'r|do-readme'     => \$do_readme,
                'w|wiki-suffix=s' => \$wiki_suffix,
                'f|from-hlubina=s' => \$hlubina_file,
                'test'          => \$test,
        );


        if( $hlubina_file ) {
                $hlubina_file =~ s{^/hlubina/}{/home/www/sklep-hlubina/};
                $move_from_dir = path($hlubina_file)->parent;
                my $dir_relative = $move_from_dir->relative($HLUBINA_ROOT_DIR);
                $foto_dir = path($HTML_DATA_DIR)->child($dir_relative);
                $wiki_suffix = "$dir_relative" =~ s{/}{-}gr;
                $wiki_suffix =~ s/^fotky-//;
                say "hlubin_file: $hlubina_file";
                say "foto_dir: $foto_dir";
                say "move_from_dir: $move_from_dir";
                say "wiki_suffix: $wiki_suffix";
                $do_index = 1;
                $do_readme = 1;
                $do_wikuk = 1;
                $do_thumnails =1;
                $want_update =1;
        }

        $wiki_file = $WIKUK_FILE if $do_wikuk;
        $wiki_file = "$foto_dir/foto.wiki" unless $wiki_file;
        $wiki_file = $wiki_file =~ s/(\.wiki)$/-$wiki_suffix$1/r if $wiki_suffix;

        usage() if ! $wiki_file ;
        usage() if $help;

        if( $test ) {
                die "argv:". pp(\@ARGV);
        }


        if( $move_from_dir ) {
                do_move_from_dir($move_from_dir, $foto_dir, $verbose);
                if( $do_readme ) {
                        do_readme($move_from_dir, $wiki_file, $verbose);
                }
        }

        if( $do_thumnails ) {
                do_thumnails($foto_dir, $verbose);
                say "thumnails done" if $verbose;
        }
        if( $do_index ) {
                update_or_create_foto_index( $foto_dir, $wiki_file, $want_update);
                say "$wiki_file done" if $verbose;
        }
}

main();
