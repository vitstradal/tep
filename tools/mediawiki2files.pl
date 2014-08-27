#!/usr/bin/perl

use XML::LibXML  '1.70';
use Data::Dump 'pp';
use utf8;

binmode STDOUT, ':utf8';

my $in = @ARGV[0];
#my $doc = XML::LibXML->new(suppress_warnings => 0, pedantic_parser=> 1,  suppress_errors => 0 , validation => 0, recover => 0)->load_xml(location=>$in);
my $doc = XML::LibXML->load_xml(location=>$in);

print "IN:$in\n";
pp($doc);
print "iscor: ", $doc->is_valid() ? 1 : 0, "\n";

for my $node ($doc->findnodes('/')) {
   print "hu @{[$node->nodeName]}\n";

   for my $page ($node->findnodes('.//page')) {
      for my $title ($page->findnodes('.//title')) {
        print "title:", $title->textContent, "\n";
      }
   }
#   for my $title ($node->findnodes('./title') ) {
#     print "@{[$title->textContent]}\n";
#   }
}


