SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";

/*
  Definitions of signs.
  type is an enum { noun, verbOrAdjective }
*/
CREATE TABLE IF NOT EXISTS `definitions` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` int(10) unsigned NOT NULL,
  `definition` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

/*
  Video URLs
*/
CREATE TABLE IF NOT EXISTS `videos` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `video` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

/*
  All the different signs. There can be many different signs for every word.
  For example, "about" has six signs.
  Every sign usually has a different video. Every sign has different keywords.
  distribution is an enum { All States, Northern Dialect, Southern Dialect, N/A }
*/
CREATE TABLE IF NOT EXISTS `signs` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `sign` text NOT NULL,
  `distribution` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

/*
  Links tables "signs" and "definitions".
  Each word can have more than one definition.
  Each definition can have more than one word.
  Many words share definitions.
*/
CREATE TABLE IF NOT EXISTS `sign_definition` (
  `sign` int(10) unsigned NOT NULL,
  `definition` int(10) unsigned NOT NULL,
  UNIQUE KEY `word_definition` (`sign`,`definition`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*
  Links table "signs" to itself to create "keyword"
  relationships.
  Each word can have many keywords.
*/
CREATE TABLE IF NOT EXISTS `sign_links` (
  `link` int(10) unsigned NOT NULL,
  `sign` int(10) unsigned NOT NULL,
  UNIQUE KEY `keyword_word` (`link`,`sign`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*
  Links tables "signs" to "videos".
  Each sign has one video.
  Each video can have many words.
*/
CREATE TABLE IF NOT EXISTS `sign_video` (
  `sign` int(10) unsigned NOT NULL,
  `video` int(10) unsigned NOT NULL,
  UNIQUE KEY `word_video` (`sign`,`video`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
