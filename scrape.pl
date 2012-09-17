#!/usr/bin/perl
use warnings;
use strict;

my %words;
my $forceRedo = 0;

if (@ARGV < 2) {
   print STDERR "Usage: ./xx A Z" . "\n";
   exit (1);
}

if (@ARGV > 2 && $ARGV[3] eq "-f") {
   $forceRedo = 1;
}

# build word database
for my $letter ($ARGV[0]..$ARGV[1]) {
   print STDERR "Processing ". $letter . "\n";
   &processLetter ($letter);
}

# download all of the files
while ((my $key, my $value) = each(%words)) {

      &processWord ($key, $value);
}

sub processLetter () {
   my ($letter) = @_;
   my $numPages = 1;
   
   my $url = "http://www.auslan.org.au/dictionary/search/?query=$letter";
   
   if (open (ROOT_CURL_STREAM, "wget -O- '$url' 2> /dev/null|")) {

      while (my $line = <ROOT_CURL_STREAM>) {
         if ($line =~ /query=[A-Z]&page=([0-9]+)'>[0-9]+<\//) {
            $numPages = $1;
         }
      }
      
      print STDERR "$numPages for letter $letter" . "\n";
      
      for my $pageNum (1..$numPages) {
         &buildWordList ($letter, $pageNum);
      }
   }
   
   return;
}

sub buildWordList () {
   my ($letter, $page) = @_;
   
   print STDERR "Processing letter $letter, page $page.." . "\n";

   my $url = "http://www.auslan.org.au/dictionary/search/?query=$letter&page=$page";
   
   if (open (ROOT_CURL_STREAM, "wget -O- '$url' 2> /dev/null|")) {
  
      while (my $line = <ROOT_CURL_STREAM>) {
      
         if ($line =~ /\<a href="\/dictionary\/words\/(.+\-[0-9]+\.html)">(.+)<\/a>/gi) {

            $words{$2} = $1;
         }
      }
   }
   
   return;
}

sub processWord () {
   my ($word, $file) = @_;
   my $numPages = 1;

   my $url = "http://www.auslan.org.au/dictionary/words/$file";
   
   if (open (ROOT_CURL_STREAM, "wget -O- '$url' 2> /dev/null|")) {

      while (my $line = <ROOT_CURL_STREAM>) {
         if ($line =~ /<span class=['"]match['"]><a href=['"]$word-([0-9]+).html['"]>[0-9]+<\/a><\/span>/) {
            $numPages = $1;
         }
      }
      
      print STDERR "$numPages for word $word" . "\n";
      
      for my $pageNum (1..$numPages) {
         &savePageToDisk("$word-$pageNum.html");
      }
   }
   
   return;
}

sub savePageToDisk () {
   my ($file) = @_;
   my $url = "http://www.auslan.org.au/dictionary/words/$file";
   my $directory = "words/".substr($file, 0, 1)."/";
   my $outputFile = "$directory/$file";
   
   $outputFile =~ s/\s+/_/gi;
   
   unless (-d $directory) {
      print STDERR "Creating directory.. $directory" . "\n";
      mkdir ($directory);
   }
   
   unless (-e $outputFile) { # TODO $forceRedo
      print STDERR "Saving to disk: $url" . "\n";
      open (ROOT_CURL_STREAM, "wget -O $outputFile '$url' 2> /dev/null|");
   }
}
