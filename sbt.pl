#!/usr/bin/perl
use warnings;
use strict;
use File::Path qw(make_path remove_tree);

# sign bank tools

my %words;
my $wordsDirectory = "words/";
my $forceRedo = 0;

if (@ARGV < 2) {
   print STDERR "Usage: ./xx [scrape|processFiles] [a-z] [a-z] [saveToDisk]" . "\n";
   exit (1);
}

if (@ARGV >= 3 && $ARGV[0] eq "scrape") {
   # build word database
   for my $letter ($ARGV[1]..$ARGV[2]) {
      print STDERR "Processing ". $letter . "\n";
      &scrapeLetter ($letter);
   }
   
   # download all of the files
   while ((my $key, my $value) = each(%words)) {
   
      if (@ARGV == 4 && $ARGV[3] eq "saveToDisk") {
         &scrapeWord ($key, $value);
      } else {
         print $key . "\n";
      }
   }
   
} elsif (@ARGV >= 3 && $ARGV[0] eq "processFiles") {

   for my $letter ($ARGV[1]..$ARGV[2]) {
   
      my $directory = $wordsDirectory . lc ($letter) . "/";
      
      my @files = <$directory*>;
      for my $file (@files) {
      
         my $signDistribution;
         my %keyWords;
      
         if (open (FILE, "< $file")) {
            while (my $line = <FILE>) {
               
               if ($line =~ /<h4>Sign Distribution<\/h4>/) {
               
                  while ($line = <FILE>) {
                     
                     if ($line =~ /<li>(.*)<\/li>/) {
                        $signDistribution = $1;
                     }
                     
                     last if $line =~ /<\/ul>/;
                  }
                  
               } elsif ($line =~ /Keywords:/) {
               
                  while ($line = <FILE>) {
                     
                     if ($line =~ /[a-z0-9_\s]+/gi) {
                        $keyWords{$1}; #TODO stopped here
                     }
                     
                     last if $line =~ /<\/p>/;
                  }
               }
            }
            
         } else {
         
            print STDERR "Could not open file: $file : $!" . "\n";
         }
      }
   }
}

sub scrapeLetter () {
   my ($letter) = @_;
   my $numPages = 1;
   
   my $url = "http://www.auslan.org.au/dictionary/search/?query=$letter";
   
   if (open (ROOT_CURL_STREAM, "wget -O- '$url' 2> /dev/null|")) {

      while (my $line = <ROOT_CURL_STREAM>) {
         if ($line =~ /query=[A-Z]&page=([0-9]+)'>[0-9]+<\//) {
            $numPages = $1;
         }
      }
      
      print STDERR "$numPages pages for letter $letter" . "\n";
      
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

sub scrapeWord () {
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
   my $directory = $wordsDirectory . substr($file, 0, 1)."/";
   my $outputFile = "$directory/$file";
   
   $outputFile =~ s/\s+/_/gi;
   
   unless (-d $directory) {
      print STDERR "Creating directory.. $directory" . "\n";
      make_path ($directory);
   }
   
   unless (-e $outputFile) { # TODO $forceRedo
      print STDERR "Saving to disk: $url" . "\n";
      open (ROOT_CURL_STREAM, "wget -O $outputFile '$url' 2> /dev/null|");
   }
}
