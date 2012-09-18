#!/usr/bin/perl
use warnings;
use strict;
use File::Path qw(make_path remove_tree);

# sign bank tools, Nakiami

my %words;
my $wordsDirectory = "words/";
my $processedDirectory = "processed/";
my $videoDirectory = "videos/";
my $forceRedo = 0;

if (@ARGV < 2) {
   print STDERR "Usage: ./xx [scrape|processFiles|downloadVideos] [a-z] [a-z] [printWordsOnly]" . "\n";
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
   
      if (@ARGV == 4 && $ARGV[3] eq "printWordsOnly") {
         print $key . "\n";
      } else {
         &scrapeWord ($key, $value);
      }
   }
   
} elsif (@ARGV >= 3 && $ARGV[0] eq "processFiles") {

   for my $letter ($ARGV[1]..$ARGV[2]) {
      print STDERR "Processing ". $letter . "\n";
      &extractInfoFromLocalFiles ($letter);
   }
   
} elsif (@ARGV >= 3 && $ARGV[0] eq "downloadVideos") {

   unless (-d $processedDirectory) {
      print STDERR "You don't have any files in your output directory!";
      exit (1);
   }

   for my $letter ($ARGV[1]..$ARGV[2]) {
      print STDERR "Processing ". $letter . "\n";
      &downloadVideos ($letter);
   }
}

sub downloadVideos () {

   my($letter) = @_;
   
   my $directory = $processedDirectory . lc ($letter) . "/";
   my @files = <$directory*>;
   
   for my $file (@files) {

      my $videoURL;

      if (open (FILE, "< $file")) {
      
         while (my $line = <FILE>) {
            
            if ($line =~ /^video:(.*)/) {
               $videoURL = $1;
               last;
            }
         }
         
         my $fileName = $file;
         $fileName =~ s/$processedDirectory//;
         my $outputDirectory = $videoDirectory . substr($fileName, 0, 1)."/";
         my $outputFile = $videoDirectory . $fileName;
         
         unless (-d $outputDirectory) {
            print STDERR "Creating directory.. $outputDirectory" . "\n";
            make_path ($outputDirectory);
         }
         
         unless (-e $outputFile) {
            print STDERR "Downloading video for $fileName.." . "\n";
            open (WGET_STREAM, "wget -O $outputFile '$videoURL' 2> /dev/null|");
         }
         
      } else {
      
         print STDERR "Could not open file: $file : $!" . "\n";
      }
   }
}

sub extractInfoFromLocalFiles () {

   my($letter) = @_;
   my $directory = $wordsDirectory . lc ($letter) . "/";
   my @files = <$directory*>;
   
   for my $file (@files) {

      my $videoURL = "N/A";
      my $signDistribution = "N/A";
      my %keyWords;
      my %nounDef;
      my %verbOrAdjectiveDef;

      if (open (FILE, "< $file")) {
      
         while (my $line = <FILE>) {
            
            if ($line =~ /url: '(.*)',/) {
               $videoURL = "http://auslan.org.au" . $1;
            }
            
            # distribution
            elsif ($line =~ /<h4>Sign Distribution<\/h4>/) {
            
               while ($line = <FILE>) {
                  
                  if ($line =~ /<li>(.*)<\/li>/) {
                     $signDistribution = $1;
                  }
                  
                  last if $line =~ /<\/ul>/;
               }
            }
            
            # keywords
            elsif ($line =~ /Keywords:/) {
            
               while ($line = <FILE>) {
               
                  $line =~ s/^\s*//;
                  $line =~ s/\s*$//;
                  
                  if ($line =~ /^([a-z0-9_\s]+)/gi) {
                     $keyWords{$1}++;
                  }
                  
                  last if $line =~ /<\/p>/;
               }
            }
            
            # noun definitions
            elsif ($line =~ /<h3>As a Noun<\/h3>/) {
            
               while ($line = <FILE>) {
               
                  if ($line =~ /<li>(.*)<\/li>/gi) {
                     
                     my $def = $1;
                     $def =~ s/^\s+//;
                     $def =~ s/\s+$//;
                     
                     $nounDef{$def}++;
                  }
                  
                  last if $line =~ /<\/ol>/;
               }
            }
            
            # noun definitions
            elsif ($line =~ /<h3>As a Verb or Adjective<\/h3>/) {
            
               while ($line = <FILE>) {
               
                  if ($line =~ /<li>(.*)<\/li>/gi) {
                     
                     my $def = $1;
                     $def =~ s/^\s+//;
                     $def =~ s/\s+$//;
                     
                     $verbOrAdjectiveDef{$def}++;
                  }
                  
                  last if $line =~ /<\/ol>/;
               }
            }
         }
         
         my $fileName = $file;
         $fileName =~ s/$wordsDirectory//;
         my $outputDirectory = $processedDirectory . substr($fileName, 0, 1)."/";
         my $outputFile = $processedDirectory . $fileName;
         $outputFile =~ s/\.html$//;
         
         unless (-d $outputDirectory) {
            print STDERR "Creating directory.. $outputDirectory" . "\n";
            make_path ($outputDirectory);
         }
         
         unless (-e $outputFile) {
         
            print STDERR "Saving to disk information from: $file" . "\n";
            if (open (OUTPUTFILE, "> $outputFile")) {
            
               print OUTPUTFILE "video:" . $videoURL . "\n";
               print OUTPUTFILE "signDistribution:" . $signDistribution . "\n";
               
               for my $key (keys (%keyWords)) {
                  print OUTPUTFILE "keyWord:" . $key . "\n";
               }
               
               for my $key (keys (%nounDef)) {
                  print OUTPUTFILE "noun:" . $key . "\n";
               }
               
               for my $key (keys (%verbOrAdjectiveDef)) {
                  print OUTPUTFILE "verbOrAdjective:" . $key . "\n";
               }
            
            } else {
            
               print STDERR "Could not open file: $file : $!" . "\n";
            }
         }
         
      } else {
      
         print STDERR "Could not open file: $file : $!" . "\n";
      }
   }
}

sub scrapeLetter () {
   my ($letter) = @_;
   my $numPages = 1;
   
   my $url = "http://www.auslan.org.au/dictionary/search/?query=$letter";
   
   if (open (WGET_STREAM, "wget -O- '$url' 2> /dev/null|")) {

      while (my $line = <WGET_STREAM>) {
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
   
   if (open (WGET_STREAM, "wget -O- '$url' 2> /dev/null|")) {
  
      while (my $line = <WGET_STREAM>) {
      
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
   
   if (open (WGET_STREAM, "wget -O- '$url' 2> /dev/null|")) {

      while (my $line = <WGET_STREAM>) {
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
   my $directory = $wordsDirectory . lc (substr ($file, 0, 1))."/";
   my $outputFile = "$directory/$file";
   
   $outputFile =~ s/\s+/_/gi;
   
   unless (-d $directory) {
      print STDERR "Creating directory.. $directory" . "\n";
      make_path ($directory);
   }
   
   unless (-e $outputFile) {
      print STDERR "Saving to disk: $url" . "\n";
      open (WGET_STREAM, "wget -O $outputFile '$url' 2> /dev/null|");
   }
}
