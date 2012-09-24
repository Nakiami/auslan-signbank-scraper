/*
  Definitions of signs.
  type is an enum { noun, verbOrAdjective }
*/
CREATE TABLE definitions (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  type INTEGER NOT NULL,
  definition text NOT NULL
);

/*
  Video URLs
*/
CREATE TABLE videos (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  video text NOT NULL
);

/*
  All the different signs. There can be many different signs for every word.
  For example, "about" has six signs.
  Every sign usually has a different video. Every sign has different keywords.
  distribution is an enum { All States, Northern Dialect, Southern Dialect, N/A }
*/
CREATE TABLE signs (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  sign text NOT NULL,
  distribution INTEGER NOT NULL
);

/*
  Links tables "signs" and "definitions".
  Each word can have more than one definition.
  Each definition can have more than one word.
  Many words share definitions.
*/
CREATE TABLE sign_definition (
  sign INTEGER NOT NULL,
  definition INTEGER NOT NULL,
  PRIMARY KEY (sign,definition)
);

/*
  Links table "signs" to itself to create "keyword"
  relationships.
  Each word can have many keywords.
*/
CREATE TABLE sign_links (
  link INTEGER NOT NULL,
  sign INTEGER NOT NULL,
  PRIMARY KEY (link,sign)
);

/*
  Links tables "signs" to "videos".
  Each sign has one video.
  Each video can have many words.
*/
CREATE TABLE sign_video (
  sign INTEGER NOT NULL,
  video INTEGER NOT NULL,
  PRIMARY KEY (sign,video)
);
