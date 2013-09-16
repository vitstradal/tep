#!/usr/bin/perl

use strict;
use warnings;
use DBIx::Simple;
use Data::Dump 'pp';

# connect
my $dbfile = $ARGV[0] || die "usage: $0 dbfile\n";
my $dbh  = DBIx::Simple->connect("dbi:SQLite:$dbfile") or die "cannt open $dbfile";

# get tables
my $tables = $dbh->select('sqlite_master', '*')->hashes;

for my $tab (@$tables) {
  my $tab_name = $tab->{name};

  print "-- $tab_name\n";
  my $rows = $dbh->select($tab_name, '*')->hashes;
  for my $row (@$rows) {
      my @cols;
      my @vals;
      for (keys %$row) {
        push(@cols, $_);
        push(@vals, $row->{$_});
      }
      print "INSERT INTO \"$tab_name\" (";
      print join(',',map{"\"$_\""} @cols);
      print ") VALUES (";
      print join(',', map{defined($_)?$dbh->dbh->quote($_):'NULL'}  @vals);
      print ");\n";
  }
}


