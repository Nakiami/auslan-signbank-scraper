#!/usr/bin/perl
use warnings;
use strict;

my %words;
my $userAgent = 'Mozilla/5.0 (X11; Linux i686 on x86_64; rv:14.0) Gecko/20100101 Firefox/14.0.1';

for my $letter ("A".."A") {
   print STDERR "Processing ". $letter . "\n";
   &processLetter ($letter);
   
   while ((my $key, my $value) = each(%words)) {
      #print $key . " ::: " . $value . "\n";
      &processWord ();
   }
}

sub processLetter () {
   my ($letter) = @_;
   my $numPages;

   my $url = "http://www.auslan.org.au/dictionary/search/?query=$letter";
   
   if (open (ROOT_CURL_STREAM, "curl -A '$userAgent' -L '$url' 2> /dev/null|")) {

      while (my $line = <ROOT_CURL_STREAM>) {
         if ($line =~ /query=$letter&page=([0-9]+)'>[0-9]+<\//) {
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
   
   if (open (ROOT_CURL_STREAM, "curl -A '$userAgent' -L '$url' 2> /dev/null|")) {
  
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
   my $numPages;

   my $url = "http://www.auslan.org.au/dictionary/words/$file";
   
   if (open (ROOT_CURL_STREAM, "curl -A '$userAgent' -L '$url' 2> /dev/null|")) {

      while (my $line = <ROOT_CURL_STREAM>) {
         if ($line =~ /<span class=['"]match['"]><a href=['"]$word-([0-9]+).html['"]>3<\/a><\/span>/) {
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
   my $numPages;
   my $url = "http://www.auslan.org.au/dictionary/words/$file";
   
   print STDERR "Saving to disk: $url" . "\n";
   
   open (ROOT_CURL_STREAM, "curl -A '$userAgent' -L '$url' 2> /dev/null > words/$file|");
}

