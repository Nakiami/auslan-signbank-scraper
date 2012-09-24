#!/usr/bin/perl
use warnings;
use strict;
use DBI;
use File::Path qw(make_path remove_tree);

# sign bank tools, Nakiami

my %words;
my %enums;
my %videos;
my %definitions;
   
my $signDirectory = "signs/";
my $processedDirectory = "processed/";
my $videoDirectory = "videos/";
my $sqlDirectory = "sql/";
my $databaseFile = "sb.db";
my $forceRedo = 0;

&buildEnums();

if (@ARGV < 2) {
   print STDERR "Usage: ./xx [scrape|processFiles|downloadVideos|populateDatabase] [a-z] [a-z] [printWordsOnly]" . "\n";
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
   
}

elsif (@ARGV >= 3 && $ARGV[0] eq "processFiles") {

   for my $letter ($ARGV[1]..$ARGV[2]) {
      print STDERR "Processing ". $letter . "\n";
      &extractInfoFromLocalFiles ($letter);
   }
   
}

elsif (@ARGV >= 3 && $ARGV[0] eq "downloadVideos") {

   unless (-d $processedDirectory) {
      print STDERR "You don't have any files in your processed directory!";
      exit (1);
   }

   for my $letter ($ARGV[1]..$ARGV[2]) {
      print STDERR "Processing ". $letter . "\n";
      &downloadVideos ($letter);
   }
}

elsif (@ARGV >= 3 && $ARGV[0] eq "populateDatabase") {

   unless (-d $processedDirectory) {
      print STDERR "You don't have any files in your processed directory!";
      exit (1);
   }

   for my $letter ($ARGV[1]..$ARGV[2]) {
      print STDERR "Populating database: ". $letter . "\n";
      &populateDatabase ($letter);
   }
   
   &writeGlobalsToDatabase();
   
   for my $letter ($ARGV[1]..$ARGV[2]) {
      print STDERR "Linking database entries: ". $letter . "\n";
      &linkDatabaseEntries ($letter);
   }
}

sub scrapeLetter () {
   my ($letter) = @_;
   my $numPages = 1;
   
   my $url = "http://www.auslan.org.au/dictionary/search/?query=$letter";
   
   if (open (WGET_STREAM, "wget -O- '$url' 2> /dev/null|")) {

      while (my $line = <WGET_STREAM>) {
         if ($line =~ /query=[A-Z]&page=([0-9]+)'>[0-9]+<\//i) {
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
   my $directory = $signDirectory . lc (substr ($file, 0, 1))."/";
   my $outputFile = "$directory/$file";
   
   $outputFile =~ s/\s+/_/gi;
   
   unless (-d $directory) {
      print STDERR "Creating directory.. $directory" . "\n";
      make_path ($directory);
   }
   
   unless (-e $outputFile) {
      print STDERR "Saving to disk: $url" . "\n";
      `wget -O $outputFile '$url' 2> /dev/null`;
   }
   
   return;
}

sub extractInfoFromLocalFiles () {

   my($letter) = @_;
   my $directory = $signDirectory . lc ($letter) . "/";
   my @files = <$directory*>;
   
   for my $file (@files) {

      my $videoURL = "N/A";
      my $signDistribution = "N/A";
      my %keywords;
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
                  
                  if ($line =~ /^([a-z0-9_\s]+),/gi) {
                     $keywords{$1}++;
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
         $fileName =~ s/$signDirectory//;
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
            
               print OUTPUTFILE "signDistribution:" . $signDistribution . "\n";
               print OUTPUTFILE "video:" . $videoURL . "\n";
               
               for my $key (keys (%keywords)) {
                  print OUTPUTFILE "keyword:" . $key . "\n";
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
   
   return;
}

sub downloadVideos () {

   my($letter) = @_;
   my %videoURLs;
   
   my $directory = $processedDirectory . lc ($letter) . "/";
   my @files = <$directory*>;
   
   for my $file (@files) {

      my $videoURL;

      if (open (FILE, "< $file")) {
      
         while (my $line = <FILE>) {
            
            if ($line =~ /^video:(.*)/) {
               $videoURLs{$1}++;
               last;
            }
         }
      }
      
      else {
         print STDERR "Could not open file: $file : $!" . "\n";
      }
   }
   
   while ((my $videoURL, my $usedNumTimes) = each(%videoURLs)) {
   
      my $outputDirectory = $videoURL;
      
      my $fileName;
      if ($outputDirectory =~ /.*\/([0-9]+\.mp4).*/) {
         $fileName = $1;
      }
      
      if($outputDirectory =~ /.*mp4video\/([0-9]+\/).*/){
         $outputDirectory = $1;
      }
      
      $outputDirectory = $videoDirectory . $outputDirectory;

      my $outputFile = $outputDirectory . $fileName;
      
      unless (-d $outputDirectory) {
         print STDERR "Creating directory.. $outputDirectory" . "\n";
         make_path ($outputDirectory);
      }
      
      unless (-e $outputFile) {
         print STDERR "Downloading video for $outputFile.." . "\n";
         `wget -O $outputFile '$videoURL' 2> /dev/null`;
      }
   }
   
   return;
}

sub populateDatabase () {
   my($letter) = @_;
   my $directory = $processedDirectory . lc ($letter) . "/";
   my @files = <$directory*>;
   
   my $dbh = DBI->connect("dbi:SQLite:dbname=".$sqlDirectory.$databaseFile, "", "", { RaiseError => 1 } ) or die $DBI::errstr;
   
   # make basic entries
   for my $file (@files) {

      my $videoURL;
      my $fileName = $file;
      if ($fileName =~ /.*\/([^\/]*)$/) {
         $fileName = $1;
      }
      
      print STDERR "Inserting " . $fileName . "\n";

      if (open (FILE, "< $file")) {
      
         while (my $line = <FILE>) {
         
            # signDistribution will always be first in the file
            if ($line =~ /^signDistribution:(.*)/) {
               $dbh->do("INSERT INTO signs (sign, distribution) VALUES ('$fileName', " . &stringToEnum($1) . ")");
            }
            
            elsif ($line =~ /^video:(.*)/) {
               $videos{$1}++;
            }
            
            # we assume that no noun definition will be the same as a verbOrAdjective definition
            elsif ($line =~ /^(noun|verbOrAdjective):(.*)/) {
               $definitions{$2} = &stringToEnum ($1);
            }
         }
      }
      
      else {
         print STDERR "Could not open file: $file : $!" . "\n";
      }
   }
   
   $dbh->disconnect();
   
   return;
}

sub writeGlobalsToDatabase () {

   my $dbh = DBI->connect("dbi:SQLite:dbname=".$sqlDirectory.$databaseFile, "", "", { RaiseError => 1 } ) or die $DBI::errstr;

   # make sure we don't have any duplicate videos
   for my $video (keys (%videos)) {
      $dbh->do("INSERT INTO videos (video) VALUES ('$video')");
   }
   
   while ((my $definition, my $type) = each (%definitions)) {
      $dbh->do("INSERT INTO definitions (type, definition) VALUES ($type, '$definition')");
   }
   
   $dbh->disconnect();

   return;
}

sub linkDatabaseEntries () {
   my($letter) = @_;
   my $directory = $processedDirectory . lc ($letter) . "/";
   my @files = <$directory*>;
   
   my $dbh = DBI->connect("dbi:SQLite:dbname=".$sqlDirectory.$databaseFile, "", "", { RaiseError => 1 } ) or die $DBI::errstr;

   # make links between entries
   for my $file (@files) {

      my $videoURL;
      my $fileName = $file;
      if ($fileName =~ /.*\/([^\/]*)$/) {
         $fileName = $1;
      }
      
      my $sth = $dbh->prepare("SELECT id FROM signs WHERE sign = '" . $fileName . "'");
      $sth->execute();
      my $signID = $sth->fetch();

      if (open (FILE, "< $file")) {
      
         while (my $line = <FILE>) {
         
            if ($line =~ /^video:(.*)/) {
            
               my $sth = $dbh->prepare("SELECT id FROM videos WHERE video = '" . $1 . "'");
               $sth->execute();
               my $videoID = $sth->fetch();
               
               $dbh->do("INSERT INTO sign_video (sign, video) VALUES (@$signID, @$videoID)");
            }
         
            elsif ($line =~ /^keyword:(.*)/) {
               my $keyword = $1;
               $keyword =~ tr/ /_/;
               
               my $sth = $dbh->prepare("SELECT id FROM signs WHERE sign LIKE ('".$keyword."-_')");
               $sth->execute();
               
               while (my $row = $sth->fetch()) {
                  $dbh->do("INSERT OR IGNORE INTO sign_links (link, sign) VALUES (@$row, @$signID)");
               }
            }
            
            elsif ($line =~ /^(noun|verbOrAdjective):(.*)/) {
               my $sth = $dbh->prepare("SELECT id FROM definitions WHERE definition = '" . $2 . "'");
               $sth->execute();
               my $definitionID = $sth->fetch();
               
               $dbh->do("INSERT INTO sign_definition (sign, definition) VALUES (@$signID, @$definitionID)");
            }
         }
      }
      
      else {
         print STDERR "Could not open file: $file : $!" . "\n";
      }
   }
   
   $dbh->disconnect();
   
   return;
}

sub stringToEnum () {
   my($string) = @_;
   return $enums{$string};
}

sub buildEnums () {
   $enums{"N/A"} = -1;
   $enums{"All States"} = 0;
   $enums{"Northern Dialect"} = 1;
   $enums{"Southern Dialect"} = 2;
   $enums{"South Australia"} = 3;
   $enums{"Victoria"} = 4;
   $enums{"New South Wales"} = 5;
   $enums{"Northern Territory"} = 6;
   $enums{"Tasmania"} = 7;
   
   $enums{"noun"} = 0;
   $enums{"verbOrAdjective"} = 1;
}
