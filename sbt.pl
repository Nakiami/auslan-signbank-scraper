#!/usr/bin/perl
use warnings;
use strict;
use DBI;
use DBIx::MultiStatementDo;
use File::Path qw(make_path remove_tree);

# sign bank tools, Nakiami

my %words;
my %enums;
my %videos;
my %definitions;
   
my $signDirectory = "signs/";
my $processedDirectory = "processed/";
my $videoDirectory = "videos/";

my $dbDirectory = "db/";
my $dbFile = "sb.db";
my $dbStructureFile = "structure.sql";
my $dbh;

&buildEnums();

if (@ARGV < 2) {
   print STDERR "Usage: ./xx [scrape|process|videos|db] [a-z] [a-z] [printOnly]" . "\n";
   exit (1);
}

if (@ARGV >= 3 && $ARGV[0] eq "scrape") {
   # build word database
   for my $letter ($ARGV[1]..$ARGV[2]) {
      print STDERR "Processing ". $letter . "\n";
      &scrapeLetter ($letter);
   }
   
   # download all of the files
   for my $key (sort ( keys (%words))) {
   
      if (@ARGV == 4 && $ARGV[3] eq "printOnly") {
         print $key . "\n";
      } else {
         &scrapeWord ($key, $words{$key});
      }
   }
   
}

elsif (@ARGV >= 3 && $ARGV[0] eq "process") {

   for my $letter ($ARGV[1]..$ARGV[2]) {
      print STDERR "Processing ". $letter . "\n";
      &extractInfoFromLocalFiles ($letter);
   }
   
}

elsif (@ARGV >= 3 && $ARGV[0] eq "videos") {

   unless (-d $processedDirectory) {
      print STDERR "You don't have any files in your processed directory!" . "\n";
      exit (1);
   }

   for my $letter ($ARGV[1]..$ARGV[2]) {
      print STDERR "Processing ". $letter . "\n";
      &downloadVideos ($letter);
   }
}

elsif (@ARGV >= 3 && $ARGV[0] eq "db") {

   unless (-d $processedDirectory) {
      print STDERR "You don't have any files in your processed directory!" . "\n";
      exit (1);
   }
   
   unless (-f $dbDirectory.$dbStructureFile) {
      print STDERR "You don't have a database structure file!" . "\n";
      exit (1);
   }
   
   if (-f $dbDirectory.$dbFile) {
      print STDERR "Database output file already exists! Move or delete it before proceeding." . "\n";
      exit (1);
   }
   
   # create our database in memory for faster processing
   $dbh = DBI->connect("dbi:SQLite:dbname=:memory:", "", "", { RaiseError => 1 } ) or die $DBI::errstr;
   
   &executeSQLFromFile ($dbDirectory.$dbStructureFile);

   for my $letter ($ARGV[1]..$ARGV[2]) {
      print STDERR "Generating database entries: ". $letter . "\n";
      &generateEntries ($letter);
   }
   
   print STDERR "Writing entries to database.." . "\n";
   &writeEntriesToDatabase();
   
   for my $letter ($ARGV[1]..$ARGV[2]) {
      print STDERR "Linking database entries: ". $letter . "\n";
      &linkDatabaseEntries ($letter);
   }
   
   # write db from memory to disk
   $dbh->sqlite_backup_to_file($dbDirectory.$dbFile);
   $dbh->disconnect();
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
      
      close(WGET_STREAM);
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
      
      print STDERR "$numPages for sign $word" . "\n";
      
      for my $pageNum (1..$numPages) {
         &savePageToDisk("$word-$pageNum.html");
      }
      
      close(WGET_STREAM);
   }
   
   return;
}

sub savePageToDisk () {
   my ($file) = @_;
   my $url = "http://www.auslan.org.au/dictionary/words/$file";
   my $directory = $signDirectory . lc (substr ($file, 0, 1))."/";
   my $outputFile = $directory.$file;
   
   $outputFile =~ s/\s+/_/gi;
   $outputFile =~ s/[^a-z0-9_\:\-\.\/]//gi; #FIXME ugly, doesn't get the words properly. Special chars mess up.
   
   unless (-d $directory) {
      print STDERR "Creating directory.. $directory" . "\n";
      make_path ($directory);
   }
   
   unless (-e $outputFile) {
      print STDERR "Saving $url to disk: $outputFile" . "\n";
      `wget -O $outputFile '$url' 2> /dev/null`;
   }
   
   else {
      print STDERR $outputFile . " already exists locally. Skipping.." . "\n";
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
               
               close(OUTPUTFILE);
            
            } else {
            
               print STDERR "Could not open file: $file : $!" . "\n";
            }
         }
         
         close(FILE);
         
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
         
         close(FILE);
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

sub generateEntries () {
   my($letter) = @_;
   my $directory = $processedDirectory . lc ($letter) . "/";
   my @files = <$directory*>;
   
   # make basic entries
   for my $file (@files) {

      my $videoURL;
      my $fileName = $file;
      if ($fileName =~ /.*\/([^\/]*)$/) {
         $fileName = $1;
      }

      if (open (FILE, "< $file")) {
      
         while (my $line = <FILE>) {
         
            # signDistribution will always be first in the file
            if ($line =~ /^signDistribution:(.*)/) {
               $words{$fileName} = &stringToEnum($1);
            }
            
            elsif ($line =~ /^video:(.*)/) {
               $videos{$1}++;
            }
            
            # we assume that no noun definition will be the same as a verbOrAdjective definition
            elsif ($line =~ /^(noun|verbOrAdjective):(.*)/) {
               $definitions{$2} = &stringToEnum ($1);
            }
         }
         
         close(FILE);
      }
      
      else {
         print STDERR "Could not open file: $file : $!" . "\n";
      }
   }
   
   return;
}

sub writeEntriesToDatabase () {

   print STDERR "Writing signs.." . "\n";
   while ((my $word, my $distribution) = each (%words)) {
      my $sth = $dbh->prepare("INSERT OR IGNORE INTO signs (sign, distribution) VALUES (?, ?)");
      $sth->execute($word, $distribution);
   }
   
   print STDERR "Writing videos.." . "\n";
   for my $video (keys (%videos)) {
      my $sth = $dbh->prepare("INSERT OR IGNORE INTO videos (video) VALUES (?)");
      $sth->execute($video);
   }
   
   print STDERR "Writing definitions.." . "\n";
   while ((my $definition, my $type) = each (%definitions)) {
      my $sth = $dbh->prepare("INSERT OR IGNORE INTO definitions (type, definition) VALUES (?, ?)");
      $sth->execute($type, $definition);
   }

   return;
}

sub linkDatabaseEntries () {
   my($letter) = @_;
   my $directory = $processedDirectory . lc ($letter) . "/";
   my @files = <$directory*>;
   
   # make links between entries
   for my $file (@files) {

      my $videoURL;
      my $fileName = $file;
      if ($fileName =~ /.*\/([^\/]*)$/) {
         $fileName = $1;
      }
      
      my $sth = $dbh->prepare("SELECT id FROM signs WHERE sign = ?");
      $sth->execute($fileName);
      my $signID = $sth->fetch();

      if (open (FILE, "< $file")) {
      
         while (my $line = <FILE>) {
         
            if ($line =~ /^video:(.*)/) {
            
               my $sth = $dbh->prepare("SELECT id FROM videos WHERE video = ?");
               $sth->execute($1);
               my $videoID = $sth->fetch();
               
               $sth = $dbh->prepare("INSERT OR IGNORE INTO sign_video (sign, video) VALUES (?, ?)");
               $sth->execute(@$signID, @$videoID);
            }
         
            elsif ($line =~ /^keyword:(.*)/) {
               my $keyword = $1;
               $keyword =~ tr/ /_/;
               $keyword =~ s/[^a-z0-9_\:\-\.\/]//gi; #FIXME ugly, doesn't get the words properly
               
               #TODO remove the vice-versa links!
               my $sth = $dbh->prepare("SELECT id FROM signs WHERE sign LIKE (?)");
               $sth->execute($keyword."-1");
               
               while (my $row = $sth->fetch()) {
                  my $sth = $dbh->prepare("INSERT OR IGNORE INTO sign_links (link, sign) VALUES (?, ?)");
                  $sth->execute(@$row, @$signID);
               }
            }
            
            elsif ($line =~ /^(noun|verbOrAdjective):(.*)/) {
               my $sth = $dbh->prepare("SELECT id FROM definitions WHERE definition = ?");
               $sth->execute($2);
               my $definitionID = $sth->fetch();
               
               $sth = $dbh->prepare("INSERT OR IGNORE INTO sign_definition (sign, definition) VALUES (?, ?)");
               $sth->execute(@$signID, @$definitionID);
            }
         }
         
         close(FILE);
      }
      
      else {
         print STDERR "Could not open file: $file : $!" . "\n";
      }
   }
   
   return;
}

sub executeSQLFromFile {
   open (FILE, shift) or die ("Can't open SQL File for reading");
   my @lines = <FILE>;
   my $SQL = join(" ", @lines); 
   close(FILE);

   # Multiple SQL statements in a single call   
   my $batch = DBIx::MultiStatementDo->new( dbh => $dbh );
   my @results = $batch->do($SQL) or die $batch->dbh->errstr;
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
   $enums{"Queensland"} = 8;
   $enums{"Western Australia"} = 9;
   
   $enums{"noun"} = 0;
   $enums{"verbOrAdjective"} = 1;
}
