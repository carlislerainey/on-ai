%% apsa.bst -- APSA author-date references for natbib
%%
%% Follows the APSA Style Manual for Political Science (2018 revision),
%% falling back on the Chicago Manual of Style (author-date) where APSA is
%% silent. Written for natbib: \bibitem[{Short(Year)Long}]{key}.
%%
%% What it does that apsr.bst / apsr_fs.bst do not:
%%   * Preprints, working papers, and unpublished manuscripts come out right
%%     regardless of how the export tool encoded them (@misc, @unpublished,
%%     @online, publisher vs. howpublished vs. note, doi vs. url).
%%     The repository is inferred from the DOI/URL when the entry only says
%%     "Center for Open Science".
%%   * DOIs are printed APSA style ("doi: 10.xxxx") and hyperlinked.
%%   * Ten or more authors -> first seven, then "et al." (APSA rule).
%%   * In text: 1-3 authors listed, 4+ -> "First et al." (APSA rule).
%%   * Page ranges abbreviated per Chicago (838--59, 101--8, 1496--1504).
%%   * Volume (Issue): pages -- the issue is never replaced by the month.
%%   * No double period after quoted titles.
%%   * Titles converted to headline-style capitalization (see below).
%%   * "The" dropped from journal names; "eds." placed as APSA shows.
%%   * Single-author works sort before coauthored works by the same author;
%%     undated and forthcoming works sort last; a/b suffixes by title.
%%
%% Title case: titles of articles, books, chapters, and unpublished work are
%% converted to headline style. Conversion only capitalizes the first letter
%% of ordinary lowercase words and lowercases a few short function words
%% ("Of", "The", "With", ...) in mid-title. It never touches text in braces,
%% math, commands, or words with digits or internal capitals (iPhone,
%% ggplot2, arXiv). Protect anything else with braces: {de Tocqueville}.
%% Turn it off for one entry with  titlecase = {no}  or for every entry by
%% changing #1 to #0 in FUNCTION {titlecase.default} below.
%%
%% Output macros (defined in the .bbl with \providecommand, so a class or
%% preamble can redefine them):
%%   \apsadoi{doi}     -> "doi: <doi>" with a link to https://doi.org/<doi>
%%   \apsapubdoi{doi}  -> DOI sentence for published works (article, book,
%%                        chapter); redefine as \newcommand\apsapubdoi[1]{}
%%                        to drop DOIs from published works only.
%%
%% Based on the label/sorting machinery of plainnat.bst (Patrick W. Daly),
%% which is itself derived from the standard BibTeX styles. Distributed
%% under the same terms: if you modify this file, rename it.

ENTRY
  { address
    archiveprefix
    author
    booktitle
    chapter
    date
    day
    doi
    edition
    editor
    eprint
    eprinttype
    howpublished
    institution
    journal
    journaltitle
    key
    location
    month
    note
    number
    organization
    pages
    publisher
    school
    series
    title
    titlecase
    type
    url
    urldate
    version
    volume
    year
  }
  {}
  { label extra.label sort.label short.list long.list
    the.year the.doi the.url the.host the.journal the.address }

STRINGS { s t x out tmp hay needle }
STRINGS { tc.in tc.out tc.word tc.core tc.ch tc.pre tc.rest }
STRINGS { pg.a pg.b pg.ch sl.s ad.s ed.s ed.t mn.s mn.t id.s id.t rp kw.t pc.t }
INTEGERS { sc.i sc.k sc.len sl.i ad.i ad.k cj ed.len }
INTEGERS { out.closed nameptr namesleft numnames limit i j k len depth }
INTEGERS { tc.force tc.next tc.first tc.p tc.ok is.repo note.used note.is.link }

% Set to #0 to switch off title-case conversion everywhere.
FUNCTION {titlecase.default} { #1 }

% ---------------------------------------------------------------------------
% Logic and string utilities
% ---------------------------------------------------------------------------

FUNCTION {not} { { #0 } { #1 } if$ }
FUNCTION {and} { 'skip$ { pop$ #0 } if$ }
FUNCTION {or}  { { pop$ #1 } 'skip$ if$ }

FUNCTION {field.or.null}
{ duplicate$ empty$
    { pop$ "" }
    'skip$
  if$
}

FUNCTION {emphasize}
{ duplicate$ empty$
    { pop$ "" }
    { "\emph{" swap$ * "}" * }
  if$
}

% hay needle str.contains -> 1 if needle occurs in hay
FUNCTION {str.contains}
{ 'needle :=
  'hay :=
  #0 'sc.k :=
  needle text.length$ 'sc.len :=
  #1 'sc.i :=
    { sc.k not  hay sc.i sc.len substring$ "" = not  and }
    { hay sc.i sc.len substring$ needle =
        { #1 'sc.k := }
        'skip$
      if$
      sc.i #1 + 'sc.i :=
    }
  while$
  sc.k
}

% hay needle str.prefix -> 1 if hay starts with needle
FUNCTION {str.prefix}
{ 'needle :=
  #1 needle text.length$ substring$ needle =
}

% s n str.from -> substring of s from character n to the end
FUNCTION {str.from}
{ global.max$ substring$ }

FUNCTION {is.digit}
{ chr.to.int$ 'cj :=
  cj #47 >  cj #58 <  and
}

FUNCTION {all.digits}
{ 'ad.s :=
  ad.s empty$
    { #0 }
    { #1 'ad.k :=
      #1 'ad.i :=
        { ad.s ad.i #1 substring$ "" = not }
        { ad.s ad.i #1 substring$ is.digit not
            { #0 'ad.k := }
            'skip$
          if$
          ad.i #1 + 'ad.i :=
        }
      while$
      ad.k
    }
  if$
}

FUNCTION {str.len}
{ 'sl.s :=
  #0 'sl.i :=
    { sl.s sl.i #1 + #1 substring$ "" = not }
    { sl.i #1 + 'sl.i := }
  while$
  sl.i
}

% single hyphens -> en dashes (issue ranges such as 2-3)
FUNCTION {dashify}
{ 'sl.s :=
  "" 
  #1 'sl.i :=
    { sl.s sl.i #1 substring$ "" = not }
    { sl.s sl.i #1 substring$ "-" =
      sl.s sl.i #1 + #1 substring$ "-" = not  and
      sl.s sl.i #1 - #1 substring$ "-" = not  and
      sl.i #1 > and
        { "--" * }
        { sl.s sl.i #1 substring$ * }
      if$
      sl.i #1 + 'sl.i :=
    }
  while$
}

% ---------------------------------------------------------------------------
% Output buffer
%   The entry is built in the global string `out`. out.closed is 1 when
%   `out` already ends a sentence (e.g., after a quoted title, whose period
%   sits inside the closing quotes), so no extra period is added.
% ---------------------------------------------------------------------------

FUNCTION {out.sentence}
{ 'x :=
  x empty$
    'skip$
    { out.closed
        { out " " * x * 'out := }
        { out add.period$ " " * x * 'out := }
      if$
      #0 'out.closed :=
    }
  if$
}

FUNCTION {out.clause}
{ 'x :=
  x empty$
    'skip$
    { out ", " * x * 'out := }
  if$
}

FUNCTION {out.quoted}
{ 'x :=
  x empty$
    'skip$
    { x add.period$ 'x :=
      out.closed
        { out " ``" * x * "''" * 'out := }
        { out add.period$ " ``" * x * "''" * 'out := }
      if$
      #1 'out.closed :=
    }
  if$
}

FUNCTION {out.finish}
{ out.closed
    'skip$
    { out add.period$ 'out := }
  if$
  out write$
  newline$
}

% ---------------------------------------------------------------------------
% Title case (headline style)
% ---------------------------------------------------------------------------

% Words never capitalized mid-title when they arrive in lowercase.
FUNCTION {tc.keep.lower}
{ 'kw.t :=
  kw.t "a" = kw.t "an" = or kw.t "the" = or kw.t "and" = or kw.t "but" = or kw.t "or" = or
  kw.t "nor" = or kw.t "for" = or kw.t "as" = or kw.t "at" = or kw.t "by" = or kw.t "in" = or
  kw.t "of" = or kw.t "on" = or kw.t "to" = or kw.t "per" = or kw.t "via" = or kw.t "vs" = or
  kw.t "vs." = or kw.t "v." = or kw.t "versus" = or kw.t "from" = or kw.t "into" = or
  kw.t "onto" = or kw.t "upon" = or kw.t "with" = or kw.t "within" = or
  kw.t "without" = or kw.t "among" = or kw.t "amid" = or kw.t "between" = or
  kw.t "beyond" = or kw.t "through" = or kw.t "throughout" = or kw.t "toward" = or
  kw.t "towards" = or kw.t "across" = or kw.t "against" = or kw.t "along" = or
  kw.t "around" = or kw.t "about" = or kw.t "above" = or kw.t "after" = or
  kw.t "before" = or kw.t "behind" = or kw.t "below" = or kw.t "beneath" = or
  kw.t "beside" = or kw.t "besides" = or kw.t "during" = or kw.t "except" = or
  kw.t "inside" = or kw.t "since" = or kw.t "than" = or kw.t "under" = or
  kw.t "until" = or kw.t "unto" = or kw.t "et" = or kw.t "al." = or kw.t "al" = or
  kw.t "e.g." = or kw.t "i.e." = or kw.t "cf." = or kw.t "etc." = or kw.t "de" = or
  kw.t "la" = or kw.t "le" = or kw.t "du" = or kw.t "van" = or kw.t "von" = or
  kw.t "der" = or kw.t "den" = or kw.t "da" = or kw.t "di" = or
}

% Short function words lowercased mid-title when typed Capitalized.
FUNCTION {tc.make.lower}
{ 'kw.t :=
  kw.t "a" = kw.t "an" = or kw.t "the" = or kw.t "and" = or kw.t "but" = or kw.t "or" = or
  kw.t "nor" = or kw.t "for" = or kw.t "as" = or kw.t "at" = or kw.t "by" = or kw.t "in" = or
  kw.t "of" = or kw.t "on" = or kw.t "to" = or kw.t "via" = or kw.t "vs." = or
  kw.t "from" = or kw.t "into" = or kw.t "onto" = or kw.t "with" = or kw.t "than" = or
  kw.t "per" = or
}

FUNCTION {is.lower}
{ chr.to.int$ 'cj :=
  cj #96 >  cj #123 <  and
}

FUNCTION {is.upper}
{ chr.to.int$ 'cj :=
  cj #64 >  cj #91 <  and
}

FUNCTION {is.lead.punct}
{ 'pc.t :=
  pc.t "(" =  pc.t "[" = or  pc.t "`" = or  pc.t "'" = or  pc.t #34 int.to.chr$ = or
}

FUNCTION {is.trail.punct}
{ 'pc.t :=
  pc.t "," = pc.t "." = or pc.t ":" = or pc.t ";" = or pc.t "?" = or pc.t "!" = or
  pc.t ")" = or pc.t "]" = or pc.t "'" = or t #34 int.to.chr$ = or
}

% Process the word in tc.word; tc.force = 1 means capitalize regardless.
% Appends the result to tc.out and sets tc.next for the following word.
FUNCTION {tc.flush}
{ % leading punctuation
  #1 'tc.p :=
    { tc.word tc.p #1 substring$ is.lead.punct
      tc.word tc.p #1 substring$ "" = not and }
    { tc.p #1 + 'tc.p := }
  while$
  tc.word #1 tc.p #1 - substring$ 'tc.pre :=
  tc.word tc.p str.from 'tc.rest :=
  % core = rest without trailing punctuation, lowercased, for list lookups
  tc.rest 'tc.core :=
  tc.core str.len 'len :=
    { len #0 >  tc.core len #1 substring$ is.trail.punct  and }
    { len #1 - 'len := }
  while$
  % a trailing period belongs to abbreviations such as "v." and "al."
  tc.core #1 len #1 + substring$ 'tmp :=
  tmp len #1 + #1 substring$ "." =
    { tmp 'tc.core := }
    { tc.core #1 len substring$ 'tc.core := }
  if$
  tc.core "l" change.case$ 'tc.core :=
  % may we touch this word at all?
  #1 'tc.ok :=
  tc.rest "" =  { #0 'tc.ok := } 'skip$ if$
  #1 'i :=
    { tc.rest i #1 substring$ "" = not  tc.ok and }
    { tc.rest i #1 substring$ 'tc.ch :=
      tc.ch "{" =  tc.ch "}" = or  tc.ch "\" = or  tc.ch "$" = or
      tc.ch "/" = or  tc.ch "_" = or  tc.ch "@" = or  tc.ch is.digit or
        { #0 'tc.ok := }
        'skip$
      if$
      i #1 >  tc.ch is.upper and
        { #0 'tc.ok := }
        'skip$
      if$
      i #1 + 'i :=
    }
  while$
  % single letter + hyphen (t-test, p-value) or a lone letter (t, p, n)
  tc.rest #2 #1 substring$ "-" =  { #0 'tc.ok := } 'skip$ if$
  tc.core str.len #1 =  tc.core "a" = not  and  { #0 'tc.ok := } 'skip$ if$
  % lowercase name opening a title, "pkg: Description" (knitr:, estimatr:)
  tc.first  tc.word str.len 'len :=  tc.word len #1 substring$ ":" =  and
  tc.rest #1 #1 substring$ is.lower  and
    { #0 'tc.ok := }
    'skip$
  if$
  tc.ok
    { tc.rest #1 #1 substring$ 'tc.ch :=
      tc.ch is.lower
        { tc.force  tc.core tc.keep.lower not  or
            { tc.ch "u" change.case$ tc.rest #2 str.from * 'tc.rest := }
            'skip$
          if$
        }
        { tc.ch is.upper  tc.force not  and  tc.core tc.make.lower  and
            { tc.ch "l" change.case$ tc.rest #2 str.from * 'tc.rest := }
            'skip$
          if$
        }
      if$
    }
    'skip$
  if$
  tc.out tc.pre * tc.rest * 'tc.out :=
  % does the next word start a new phrase?
  tc.word str.len 'len :=
    { len #1 >
      tc.word len #1 substring$ ")" =
      tc.word len #1 substring$ "'" = or
      tc.word len #1 substring$ #34 int.to.chr$ = or  and }
    { len #1 - 'len := }
  while$
  tc.word len #1 substring$ 'tc.ch :=
  tc.ch ":" =  tc.ch "?" = or  tc.ch "!" = or  tc.word "---" = or
  tc.word "--" = or
  tc.ch "." =  len #2 >  and  tc.core tc.keep.lower not  and  or
    { #1 'tc.next := }
    { #0 'tc.next := }
  if$
  "" 'tc.word :=
}

% s titlecase.apply -> s in headline style
FUNCTION {titlecase.apply}
{ 'tc.in :=
  "" 'tc.out :=
  "" 'tc.word :=
  #0 'depth :=
  #1 'tc.next :=
  #1 'tc.first :=
  #1 'k :=
    { tc.in k #1 substring$ "" = not }
    { tc.in k #1 substring$ 'tc.ch :=
      tc.ch "{" = { depth #1 + 'depth := } 'skip$ if$
      tc.ch "}" = { depth #1 - 'depth := } 'skip$ if$
      tc.ch " " =  depth #0 =  and
        { tc.word empty$
            'skip$
            { tc.next 'tc.force :=
              tc.flush
              #0 'tc.first :=
            }
          if$
          tc.out " " * 'tc.out :=
        }
        { tc.word tc.ch * 'tc.word := }
      if$
      k #1 + 'k :=
    }
  while$
  tc.word empty$
    'skip$
    { #1 'tc.force :=      % the last word is always capitalized
      tc.flush
    }
  if$
  tc.out
}

FUNCTION {titlecase.wanted}
{ titlecase empty$
    { titlecase.default }
    { titlecase "l" change.case$ 't :=
      t "no" =  t "false" = or  t "0" = or  t "off" = or
        { #0 }
        { #1 }
      if$
    }
  if$
}

FUNCTION {tc}
{ duplicate$ empty$
    'skip$
    { titlecase.wanted
        'titlecase.apply
        'skip$
      if$
    }
  if$
}

% ---------------------------------------------------------------------------
% Names
% ---------------------------------------------------------------------------

% Reference-list names: first author inverted, the rest in normal order.
% Ten or more authors -> first seven, then "et al." (APSA).
FUNCTION {format.names}
{ 's :=
  s num.names$ 'numnames :=
  numnames #9 >
    { #7 'limit := }
    { numnames 'limit := }
  if$
  #1 'nameptr :=
  ""
    { nameptr limit #1 + < }
    { nameptr #1 =
        { s nameptr "{vv~}{ll}{, ff}{, jj}" format.name$ * }
        { s nameptr "{ff~}{vv~}{ll}{ jj}" format.name$ 't :=
          t "others" =
            { #0 'limit := }
            { nameptr limit =  limit numnames =  and
                { ", and " * t * }
                { ", " * t * }
              if$
            }
          if$
        }
      if$
      nameptr #1 + 'nameptr :=
    }
  while$
  limit numnames <
    { ", et~al." * }
    'skip$
  if$
}

% Editors inside a chapter reference: all in normal order.
FUNCTION {format.names.plain}
{ 's :=
  s num.names$ 'numnames :=
  #1 'nameptr :=
  ""
    { nameptr numnames #1 + < }
    { s nameptr "{ff~}{vv~}{ll}{ jj}" format.name$ 't :=
      nameptr #1 =
        { t * }
        { t "others" =
            { " et~al." * }
            { nameptr numnames =
                { numnames #2 >
                    { ", and " * t * }
                    { " and " * t * }
                  if$
                }
                { ", " * t * }
              if$
            }
          if$
        }
      if$
      nameptr #1 + 'nameptr :=
    }
  while$
}

FUNCTION {editor.word}
{ editor num.names$ #1 >
    { "eds." }
    { "ed." }
  if$
}

% Citation label: 1-3 authors listed, 4 or more -> "First et al."
FUNCTION {format.lab.names}
{ 's :=
  s num.names$ 'numnames :=
  s #1 "{vv~}{ll}" format.name$
  numnames #1 >
    { numnames #3 >
      s numnames "{ff }{vv }{ll}{ jj}" format.name$ "others" = or
        { " et~al." * }
        { numnames #2 =
            { " and " * s #2 "{vv~}{ll}" format.name$ * }
            { ", " * s #2 "{vv~}{ll}" format.name$ *
              ", and " * s #3 "{vv~}{ll}" format.name$ * }
          if$
        }
      if$
    }
    'skip$
  if$
}

% Long label for \citet*: every surname.
FUNCTION {format.full.names}
{ 's :=
  s num.names$ 'numnames :=
  #1 'nameptr :=
  ""
    { nameptr numnames #1 + < }
    { s nameptr "{vv~}{ll}" format.name$ 't :=
      nameptr #1 =
        { t * }
        { t "others" =
            { " et~al." * }
            { nameptr numnames =
                { numnames #2 >
                    { ", and " * t * }
                    { " and " * t * }
                  if$
                }
                { ", " * t * }
              if$
            }
          if$
        }
      if$
      nameptr #1 + 'nameptr :=
    }
  while$
}

FUNCTION {editors.as.authors}
{ type$ "book" =  type$ "inbook" = or  type$ "proceedings" = or
  type$ "booklet" = or  type$ "collection" = or
}

FUNCTION {org.name}
{ organization empty$
    { institution empty$
        { "" }
        { institution }
      if$
    }
    { organization }
  if$
}

% Who goes in the author slot: author, else editor (books), else
% organization, else nothing (the title leads).
FUNCTION {name.source}
{ author empty$
    { editor empty$ not  editors.as.authors  and
        { editor }
        { org.name }
      if$
    }
    { author }
  if$
}

% Up to the first colon or four words, for citing a work with no author.
FUNCTION {short.title}
{ 's :=
  "" 't :=
  #0 'k :=
  #0 'depth :=
  #1 'i :=
    { s i #1 substring$ "" = not  k #4 <  and }
    { s i #1 substring$ 'x :=
      x "{" = { depth #1 + 'depth := } 'skip$ if$
      x "}" = { depth #1 - 'depth := } 'skip$ if$
      x ":" =  depth #0 =  and
        { #4 'k := }
        { x " " =  depth #0 =  and  { k #1 + 'k := } 'skip$ if$
          k #4 < { t x * 't := } 'skip$ if$
        }
      if$
      i #1 + 'i :=
    }
  while$
  t
}

FUNCTION {calc.labels}
{ author empty$
    { editor empty$ not  editors.as.authors  and
        { editor format.lab.names 'short.list :=
          editor format.full.names 'long.list := }
        { org.name empty$
            { key empty$
                { title empty$
                    { cite$ }
                    { "``" title short.title * "''" * }
                  if$
                }
                { key }
              if$
              'short.list :=
            }
            { org.name 'short.list := }
          if$
          short.list 'long.list :=
        }
      if$
    }
    { author format.lab.names 'short.list :=
      % \citet* lists every surname; past nine it is "et al." anyway
      author num.names$ #9 >
        { short.list }
        { author format.full.names }
      if$
      'long.list := }
  if$
}

% ---------------------------------------------------------------------------
% Field normalization
% ---------------------------------------------------------------------------

FUNCTION {calc.year}
{ year empty$
    { date empty$
        { "" }
        { date #1 #4 substring$ }
      if$
    }
    { year }
  if$
  'the.year :=
}

FUNCTION {is.forthcoming}
{ the.year "l" change.case$ "forthcoming" =
  the.year "l" change.case$ "in press" = or
}

FUNCTION {year.label}
{ the.year empty$
    { "n.d." }
    { is.forthcoming
        { "forthcoming" }
        { the.year }
      if$
    }
  if$
}

FUNCTION {year.list}
{ the.year empty$
    { "n.d." }
    { is.forthcoming
        { "Forthcoming" }
        { the.year }
      if$
    }
  if$
}

FUNCTION {year.sort}
{ the.year empty$
    { "9999" }
    { is.forthcoming
        { "9998" }
        { the.year }
      if$
    }
  if$
}

% Strip resolver prefixes from a DOI.
FUNCTION {clean.doi}
{ 's :=
  s "https://doi.org/" str.prefix    { s #17 str.from 's := } 'skip$ if$
  s "http://doi.org/" str.prefix     { s #16 str.from 's := } 'skip$ if$
  s "https://dx.doi.org/" str.prefix { s #20 str.from 's := } 'skip$ if$
  s "http://dx.doi.org/" str.prefix  { s #19 str.from 's := } 'skip$ if$
  s "doi: " str.prefix               { s #6 str.from 's := } 'skip$ if$
  s "doi:" str.prefix                { s #5 str.from 's := } 'skip$ if$
  s "DOI: " str.prefix               { s #6 str.from 's := } 'skip$ if$
  s
}

FUNCTION {url.is.doi}
{ 's :=
  s "doi.org/10." str.contains
}

FUNCTION {looks.like.url}
{ 's :=
  s "." str.contains  s "/" str.contains  or
  s " " str.contains not  and
}

FUNCTION {calc.links}
{ doi empty$
    { url empty$
        { "" }
        { url url.is.doi
            { url clean.doi }
            { "" }
          if$
        }
      if$
    }
    { doi clean.doi }
  if$
  'the.doi :=
  "" 'the.url :=
  url empty$ not
    { url url.is.doi not  url looks.like.url  and
        { url "http" str.prefix
            { url }
            { "https://" url * }
          if$
          'the.url :=
        }
        'skip$
      if$
    }
    'skip$
  if$
  % arXiv eprint without a URL
  the.url empty$  eprint empty$ not  and
    { archiveprefix field.or.null "l" change.case$ "arxiv" =
      eprinttype field.or.null "l" change.case$ "arxiv" = or
        { "https://arxiv.org/abs/" eprint * 'the.url := }
        'skip$
      if$
    }
    'skip$
  if$
}

FUNCTION {calc.journal}
{ journal empty$
    { journaltitle field.or.null }
    { journal }
  if$
  's :=
  s "The " str.prefix
    { s #5 str.from }
    { s }
  if$
  'the.journal :=
}

FUNCTION {calc.address}
{ address empty$
    { location field.or.null }
    { address }
  if$
  'the.address :=
}

FUNCTION {month.name}
{ 'mn.s :=
  mn.s "l" change.case$ 'mn.t :=
  mn.t "jan" = mn.t "1" = or mn.t "01" = or { "January" } {
  mn.t "feb" = mn.t "2" = or mn.t "02" = or { "February" } {
  mn.t "mar" = mn.t "3" = or mn.t "03" = or { "March" } {
  mn.t "apr" = mn.t "4" = or mn.t "04" = or { "April" } {
  mn.t "may" = mn.t "5" = or mn.t "05" = or { "May" } {
  mn.t "jun" = mn.t "6" = or mn.t "06" = or { "June" } {
  mn.t "jul" = mn.t "7" = or mn.t "07" = or { "July" } {
  mn.t "aug" = mn.t "8" = or mn.t "08" = or { "August" } {
  mn.t "sep" = mn.t "sept" = or mn.t "9" = or mn.t "09" = or { "September" } {
  mn.t "oct" = mn.t "10" = or { "October" } {
  mn.t "nov" = mn.t "11" = or { "November" } {
  mn.t "dec" = mn.t "12" = or { "December" } { mn.s }
  if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$
}

FUNCTION {format.month.day}
{ month empty$
    { "" }
    { month month.name
      day empty$
        'skip$
        { " " * day * }
      if$
    }
  if$
}

% 2024-10-11 -> October 11, 2024 (anything else is returned unchanged)
FUNCTION {format.iso.date}
{ 'id.s :=
  id.s str.len #10 =  id.s #5 #1 substring$ "-" =  and  id.s #8 #1 substring$ "-" =  and
    { id.s #6 #2 substring$ month.name " " *
      id.s #9 #2 substring$ 'id.t :=
      id.t #1 #1 substring$ "0" =
        { id.t #2 #1 substring$ 'id.t := }
        'skip$
      if$
      id.t * ", " * id.s #1 #4 substring$ *
    }
    { id.s }
  if$
}

% Edition: 2 -> 2nd edition; Second -> 2nd edition; 2nd -> 2nd edition.
FUNCTION {format.edition}
{ edition empty$
    { "" }
    { edition "l" change.case$ 'ed.t :=
      ed.t "first" = { "1st" 'ed.s := } {
      ed.t "second" = { "2nd" 'ed.s := } {
      ed.t "third" = { "3rd" 'ed.s := } {
      ed.t "fourth" = { "4th" 'ed.s := } {
      ed.t "fifth" = { "5th" 'ed.s := } {
      ed.t "sixth" = { "6th" 'ed.s := } {
      ed.t "seventh" = { "7th" 'ed.s := } {
      ed.t "eighth" = { "8th" 'ed.s := } {
      ed.t "ninth" = { "9th" 'ed.s := } {
      ed.t "tenth" = { "10th" 'ed.s := } { edition 'ed.s := }
      if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$
      ed.s all.digits
        { ed.s str.len 'ed.len :=
          ed.s ed.len #1 substring$ 'ed.t :=
          ed.len #1 >  ed.s ed.len #1 - #1 substring$ "1" =  and
            { ed.s "th" * }
            { ed.t "1" = { ed.s "st" * } {
              ed.t "2" = { ed.s "nd" * } {
              ed.t "3" = { ed.s "rd" * } { ed.s "th" * }
              if$ } if$ } if$ }
          if$
          'ed.s :=
        }
        'skip$
      if$
      ed.s "l" change.case$ 'ed.t :=
      ed.t "edition" str.contains  ed.t "ed." str.contains  or
        { ed.s }
        { ed.s " edition" * }
      if$
    }
  if$
}

% ---------------------------------------------------------------------------
% Pages: Chicago inclusive numbers (CMOS 9.61)
% ---------------------------------------------------------------------------

FUNCTION {abbrev.range}
{ % uses pg.a and pg.b (digit strings); leaves result on stack
  pg.a str.len 'i :=
  pg.b str.len 'j :=
  i j = not  i #3 <  or  pg.a i #1 - #2 substring$ "00" =  or
    { pg.b }
    { #1 'k :=
        { k i < pg.a k #1 substring$ pg.b k #1 substring$ = and }
        { k #1 + 'k := }
      while$
      i #4 =  k #3 <  and
        { pg.b }
        { pg.a i #1 - #1 substring$ "0" =
            { pg.b k str.from }
            { k i #1 - >
                { pg.b i #1 - str.from }
                { pg.b k str.from }
              if$
            }
          if$
        }
      if$
    }
  if$
}

FUNCTION {format.pages}
{ pages empty$
    { "" }
    { "" 'pg.a :=
      "" 'pg.b :=
      #0 'depth :=        % 0 = reading first number, 1 = in dash, 2 = second
      #1 'i :=
        { pages i #1 substring$ "" = not }
        { pages i #1 substring$ 'pg.ch :=
          pg.ch "-" =
            { depth #2 < { #1 'depth := } { pg.b pg.ch * 'pg.b := } if$
              i #1 + 'i := }
            { pages i #3 substring$ "–" =  pages i #3 substring$ "—" = or
                { depth #2 < { #1 'depth := } 'skip$ if$
                  i #3 + 'i := }
                { pg.ch " " = pg.ch "~" = or
                    'skip$
                    { depth #0 =
                        { pg.a pg.ch * 'pg.a := }
                        { #2 'depth :=  pg.b pg.ch * 'pg.b := }
                      if$
                    }
                  if$
                  i #1 + 'i :=
                }
              if$
            }
          if$
        }
      while$
      pg.b empty$
        { pg.a }
        { pg.a all.digits  pg.b all.digits  and
            { pg.a "--" * abbrev.range * }
            { pg.a "--" * pg.b * }
          if$
        }
      if$
    }
  if$
}

% ---------------------------------------------------------------------------
% Repositories for preprints and working papers
% ---------------------------------------------------------------------------

FUNCTION {repo.from.links}
{ the.doi "10.31235/" str.prefix { "SocArXiv" } {
  the.doi "10.31234/" str.prefix { "PsyArXiv" } {
  the.doi "10.31219/" str.prefix { "OSF Preprints" } {
  the.doi "10.31222/" str.prefix { "MetaArXiv" } {
  the.doi "10.48550/" str.prefix { "arXiv" } {
  the.doi "10.2139/ssrn" str.prefix { "SSRN" } {
  the.url "osf.io/preprints/socarxiv" str.contains { "SocArXiv" } {
  the.url "osf.io/preprints/psyarxiv" str.contains { "PsyArXiv" } {
  the.url "osf.io/preprints/metaarxiv" str.contains { "MetaArXiv" } {
  the.url "osf.io/preprints/osf" str.contains { "OSF Preprints" } {
  the.url "arxiv.org/" str.contains { "arXiv" } {
  the.url "ssrn.com/" str.contains { "SSRN" } { "" }
  if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$
}

FUNCTION {is.generic.host}
{ "l" change.case$ 'rp :=
  rp "center for open science" =  rp "open science framework" = or
  rp "osf" = or  rp "osf.io" = or
}

FUNCTION {is.known.repo}
{ "l" change.case$ 'rp :=
  rp "socarxiv" =  rp "psyarxiv" = or  rp "metaarxiv" = or
  rp "osf preprints" = or  rp "osf" = or  rp "arxiv" = or  rp "ssrn" = or
  rp "biorxiv" = or  rp "medrxiv" = or  rp "edarxiv" = or
  rp "lawarxiv" = or  rp "research square" = or  rp "preprints.org" = or
  rp "zenodo" = or  rp "econstor" = or  rp "repec" = or
}

FUNCTION {is.link.text}
{ 's :=
  s "\url" str.contains  s "http" str.contains  or  s "\href" str.contains  or
}

% Sets the.host and is.repo for unpublished-type entries.
FUNCTION {calc.host}
{ howpublished empty$ not  howpublished field.or.null is.link.text not  and
    { howpublished }
    { publisher empty$ not
        { publisher }
        { institution empty$ not
            { institution }
            { organization empty$ not
                { organization }
                { archiveprefix empty$ not
                    { archiveprefix }
                    { eprinttype field.or.null }
                  if$
                }
              if$
            }
          if$
        }
      if$
    }
  if$
  's :=
  repo.from.links 'tmp :=
  s empty$  s is.generic.host  or
    { tmp empty$
        { s empty$
            { "" 'the.host :=  #0 'is.repo := }
            { "OSF" 'the.host :=  #1 'is.repo := }
          if$
        }
        { tmp 'the.host :=  #1 'is.repo := }
      if$
    }
    { s 'the.host :=
      s is.known.repo 'is.repo :=
    }
  if$
}

% ---------------------------------------------------------------------------
% Pieces shared by the entry types
% ---------------------------------------------------------------------------

FUNCTION {begin.entry}
{ calc.year
  calc.links
  calc.journal
  calc.address
  "" 'out :=
  #1 'out.closed :=
  name.source empty$
    'skip$
    { name.source format.names
      author empty$  editor empty$ not  and  editors.as.authors  and
        { ", " * editor.word * }
        'skip$
      if$
      'out :=
      #0 'out.closed :=
    }
  if$
  % with no author, the title leads and the year follows it
  name.source empty$
    { title empty$ not
        { "``" title tc add.period$ * "''" * 'out :=
          #1 'out.closed := }
        'skip$
      if$
    }
    'skip$
  if$
  year.list extra.label * out.sentence
}

FUNCTION {quoted.title}
{ name.source empty$
    'skip$
    { title tc out.quoted }
  if$
}

FUNCTION {emph.title}
{ title empty$
    'skip$
    { title tc emphasize out.sentence }
  if$
}

FUNCTION {publisher.part}
{ publisher empty$
    { the.address }
    { the.address empty$
        { publisher }
        { the.address ": " * publisher * }
      if$
    }
  if$
}

FUNCTION {out.pubdoi}
{ the.doi empty$
    'skip$
    { out.closed
        'skip$
        { out add.period$ 'out := }
      if$
      out " \apsapubdoi{" * the.doi * "}" * 'out :=
      #1 'out.closed :=
    }
  if$
}

FUNCTION {out.id}
{ the.doi empty$
    { the.url empty$
        'skip$
        { "\url{" the.url * "}" * out.sentence }
      if$
    }
    { "\apsadoi{" the.doi * "}" * out.sentence }
  if$
}

FUNCTION {out.note}
{ note empty$
    'skip$
    { note out.sentence }
  if$
}

% ---------------------------------------------------------------------------
% Entry types
% ---------------------------------------------------------------------------

FUNCTION {output.bibitem}
{ newline$
  "\bibitem[{" short.list * "(" * year.label * extra.label * ")" *
  long.list *
  "}]{" * cite$ * "}" * write$
  newline$
}

FUNCTION {article.body}
{ output.bibitem
  begin.entry
  quoted.title
  the.journal emphasize 's :=
  volume empty$
    { the.doi empty$
        { % newspaper or magazine
          s format.month.day 't :=
          t empty$ 'skip$ { ", " * t * } if$
          pages empty$ 'skip$ { ", " * format.pages * } if$
          out.sentence
          the.url empty$ 'skip$ { "\url{" the.url * "}" * out.sentence } if$
        }
        { % published online, not yet in an issue
          s out.sentence
          out.pubdoi
        }
      if$
    }
    { s " " * volume *
      number empty$
        { month empty$ 'skip$ { " (" * month month.name * ")" * } if$ }
        { " (" * number dashify * ")" * }
      if$
      pages empty$ 'skip$ { ": " * format.pages * } if$
      out.sentence
      out.pubdoi
    }
  if$
  out.note
  out.finish
}

FUNCTION {book}
{ output.bibitem
  begin.entry
  title empty$
    'skip$
    { title tc emphasize
      format.edition 't :=
      t empty$ 'skip$ { ", " * t * } if$
      name.source empty$ { pop$ } { out.sentence } if$
    }
  if$
  series empty$
    'skip$
    { series number empty$ 'skip$ { " " * number * } if$ out.sentence }
  if$
  publisher.part out.sentence
  out.pubdoi
  out.note
  out.finish
}

FUNCTION {incollection}
{ output.bibitem
  begin.entry
  quoted.title
  booktitle empty$
    'skip$
    { "In " booktitle tc emphasize * 's :=
      format.edition 't :=
      t empty$ 'skip$ { s ", " * t * 's := } if$
      editor empty$
        'skip$
        { s ", " * editor.word * " " * editor format.names.plain * 's := }
      if$
      pages empty$ 'skip$ { s ", " * format.pages * 's := } if$
      s out.sentence
    }
  if$
  publisher.part out.sentence
  out.pubdoi
  out.note
  out.finish
}

FUNCTION {inbook}
{ booktitle empty$
    'book
    'incollection
  if$
}

FUNCTION {inproceedings}
{ publisher empty$  pages empty$  and
    { output.bibitem
      begin.entry
      quoted.title
      type empty$ { "Paper presented at" } { type } if$ 's :=
      booktitle empty$
        'skip$
        { booktitle 't :=
          t "the " str.prefix  t "The " str.prefix or
            { t #5 str.from 't := }
            'skip$
          if$
          s " the " * t * 's :=
          the.address empty$ 'skip$ { s ", " * the.address * 's := } if$
        }
      if$
      s out.sentence
      out.note
      out.id
      out.finish
    }
    'incollection
  if$
}

FUNCTION {conference} { inproceedings }

FUNCTION {thesis.common}
{ output.bibitem
  begin.entry
  quoted.title
  type empty$ 'skip$ { pop$ type } if$ out.sentence
  school empty$ { institution field.or.null } { school } if$ out.sentence
  out.note
  out.id
  out.finish
}

FUNCTION {phdthesis} { "PhD diss." thesis.common }
FUNCTION {mastersthesis} { "Master's thesis." thesis.common }
FUNCTION {thesis} { "PhD diss." thesis.common }

FUNCTION {techreport}
{ output.bibitem
  begin.entry
  quoted.title
  type empty$
    { number empty$ { "" } { "Report" } if$ }
    { type }
  if$
  number empty$ 'skip$ { " " * number * } if$
  's :=
  institution empty$
    'skip$
    { s empty$ { institution } { s ", " * institution * } if$ 's :=
      the.address empty$ 'skip$ { s ", " * the.address * 's := } if$
    }
  if$
  s out.sentence
  out.note
  out.id
  out.finish
}

FUNCTION {report} { techreport }

% Unpublished manuscripts, working papers, and preprints.
FUNCTION {unpublished}
{ output.bibitem
  begin.entry
  quoted.title
  calc.host
  note empty$ { #0 } { note is.link.text } if$ 'note.is.link :=
  #0 'note.used :=
  type empty$ not
    { type }
    { note empty$ not  note.is.link not  and
        { #1 'note.used :=  note }
        { is.repo
            { "Preprint" }
            { type$ "unpublished" =  the.host empty$  and
                { "Unpublished manuscript" }
                { "" }
              if$
            }
          if$
        }
      if$
    }
  if$
  's :=
  the.host empty$
    'skip$
    { s empty$
        { the.host 's := }
        { s the.host str.contains
            'skip$
            { s ", " * the.host * 's := }
          if$
        }
      if$
    }
  if$
  s out.sentence
  note.used not  note.is.link not  and
    'out.note
    'skip$
  if$
  the.doi empty$  the.url empty$  and  note.is.link  and
    'out.note
    'out.id
  if$
  out.finish
}

% An @article with no journal is a preprint exported as an article.
FUNCTION {article}
{ journal empty$  journaltitle empty$  and
    'unpublished
    'article.body
  if$
}

FUNCTION {misc} { unpublished }
FUNCTION {preprint} { unpublished }

% Web pages and blog posts.
FUNCTION {online}
{ output.bibitem
  begin.entry
  quoted.title
  the.journal empty$
    { org.name empty$
        { howpublished empty$ not  howpublished field.or.null is.link.text not  and
            { howpublished }
            { publisher field.or.null }
          if$
        }
        { org.name }
      if$
      % do not repeat an organization that is already the author
      's :=
      s name.source = { "" } { s } if$
    }
    { journal empty$ { journaltitle } { journal } if$ 's :=
      s " [blog]" str.contains
        { s str.len #7 - 'len :=
          s #1 len substring$ emphasize " [blog]" * }
        { s emphasize }
      if$
    }
  if$
  format.month.day 't :=
  t empty$ 'skip$ { duplicate$ empty$ { pop$ t } { ", " * t * } if$ } if$
  out.sentence
  out.note
  the.year empty$  urldate empty$ not  and
    { "Accessed " urldate format.iso.date * out.sentence }
    'skip$
  if$
  out.id
  out.finish
}

FUNCTION {electronic} { online }
FUNCTION {www} { online }
FUNCTION {webpage} { online }

% Software and manuals: italic title, no case change.
FUNCTION {manual}
{ output.bibitem
  begin.entry
  title emphasize out.sentence
  version empty$ 'skip$ { "Version " version * out.sentence } if$
  out.note
  publisher empty$ { org.name } { publisher } if$ 's :=
  s name.source = { "" 's := } 'skip$ if$
  the.address empty$
    'skip$
    { s empty$ { the.address } { the.address ": " * s * } if$ 's := }
  if$
  s out.sentence
  out.id
  out.finish
}

FUNCTION {software} { manual }

FUNCTION {dataset}
{ output.bibitem
  begin.entry
  quoted.title
  version empty$ 'skip$ { "Version " version * out.sentence } if$
  publisher empty$
    { org.name empty$ { howpublished field.or.null } { org.name } if$ }
    { publisher }
  if$
  out.sentence
  out.note
  out.id
  out.finish
}

FUNCTION {data} { dataset }

FUNCTION {booklet} { book }
FUNCTION {proceedings} { book }
FUNCTION {collection} { book }

FUNCTION {default.type} { misc }

MACRO {jan} {"January"}
MACRO {feb} {"February"}
MACRO {mar} {"March"}
MACRO {apr} {"April"}
MACRO {may} {"May"}
MACRO {jun} {"June"}
MACRO {jul} {"July"}
MACRO {aug} {"August"}
MACRO {sep} {"September"}
MACRO {oct} {"October"}
MACRO {nov} {"November"}
MACRO {dec} {"December"}

READ

% ---------------------------------------------------------------------------
% Labels, a/b suffixes, and sorting
% ---------------------------------------------------------------------------

% Fold common accented UTF-8 letters to their base letter for sorting,
% so that "P\'erez" and "Pérez" both sort as "Perez".
STRINGS { fu.in fu.out fu.c }
INTEGERS { fu.i }

FUNCTION {utf8.base}
{ 'fu.c :=
  fu.c "à" = fu.c "á" = or fu.c "â" = or fu.c "ã" = or fu.c "ä" = or fu.c "å" = or fu.c "À" = or fu.c "Á" = or fu.c "Â" = or fu.c "Ã" = or fu.c "Ä" = or fu.c "Å" = or fu.c "ą" = or
    { "a" } {
  fu.c "ç" = fu.c "Ç" = or fu.c "č" = or fu.c "ć" = or fu.c "Č" = or fu.c "Ć" = or
    { "c" } {
  fu.c "è" = fu.c "é" = or fu.c "ê" = or fu.c "ë" = or fu.c "È" = or fu.c "É" = or fu.c "Ê" = or fu.c "Ë" = or fu.c "ě" = or fu.c "Ě" = or fu.c "ę" = or
    { "e" } {
  fu.c "ì" = fu.c "í" = or fu.c "î" = or fu.c "ï" = or fu.c "Ì" = or fu.c "Í" = or fu.c "Î" = or fu.c "Ï" = or fu.c "ı" = or fu.c "İ" = or
    { "i" } {
  fu.c "ñ" = fu.c "Ñ" = or fu.c "ń" = or fu.c "Ń" = or fu.c "ň" = or
    { "n" } {
  fu.c "ò" = fu.c "ó" = or fu.c "ô" = or fu.c "õ" = or fu.c "ö" = or fu.c "ø" = or fu.c "Ò" = or fu.c "Ó" = or fu.c "Ô" = or fu.c "Õ" = or fu.c "Ö" = or fu.c "Ø" = or fu.c "ő" = or
    { "o" } {
  fu.c "ù" = fu.c "ú" = or fu.c "û" = or fu.c "ü" = or fu.c "Ù" = or fu.c "Ú" = or fu.c "Û" = or fu.c "Ü" = or fu.c "ű" = or fu.c "ů" = or
    { "u" } {
  fu.c "ý" = fu.c "ÿ" = or fu.c "Ý" = or
    { "y" } {
  fu.c "š" = fu.c "Š" = or fu.c "ś" = or fu.c "Ś" = or fu.c "ş" = or fu.c "Ş" = or
    { "s" } {
  fu.c "ž" = fu.c "Ž" = or fu.c "ź" = or fu.c "ż" = or fu.c "Ź" = or fu.c "Ż" = or
    { "z" } {
  fu.c "ł" = fu.c "Ł" = or
    { "l" } {
  fu.c "ğ" = fu.c "Ğ" = or
    { "g" } {
  fu.c "ř" = fu.c "Ř" = or
    { "r" } {
  fu.c "đ" = fu.c "Đ" = or
    { "d" } {
  fu.c "ţ" =
    { "t" } {
  ""
  } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ } if$ 
}

FUNCTION {fold.utf8}
{ 'fu.in :=
  "" 'fu.out :=
  #1 'fu.i :=
    { fu.in fu.i #1 substring$ "" = not }
    { fu.in fu.i #1 substring$ chr.to.int$ #127 >
        { fu.in fu.i #2 substring$ utf8.base 'tmp :=
          tmp empty$
            { fu.out fu.in fu.i #1 substring$ * 'fu.out :=  fu.i #1 + 'fu.i := }
            { fu.out tmp * 'fu.out :=  fu.i #2 + 'fu.i := }
          if$
        }
        { fu.out fu.in fu.i #1 substring$ * 'fu.out :=  fu.i #1 + 'fu.i := }
      if$
    }
  while$
  fu.out
}

FUNCTION {sortify}
{ fold.utf8
  purify$
  "l" change.case$
}

FUNCTION {chop.word}
{ 's :=
  'len :=
  s #1 len substring$ =
    { s len #1 + global.max$ substring$ }
    's
  if$
}

FUNCTION {sort.format.title}
{ 't :=
  "A " #2
    "An " #3
      "The " #4 t chop.word
    chop.word
  chop.word
  sortify
  #1 global.max$ substring$
}

% Names for sorting: letter by letter through every author, so a single
% author precedes coauthored works and coauthors break ties (APSA, CMOS 15.17).
FUNCTION {sort.format.names}
{ 's :=
  #1 'nameptr :=
  ""
  s num.names$ 'numnames :=
  numnames 'namesleft :=
    { namesleft #0 > }
    { s nameptr "{vv{ } }{ll{ }}{  ff{ }}{  jj{ }}" format.name$ 't :=
      nameptr #1 >
        { "   " *
          namesleft #1 =  t "others" =  and
            { "zzzzz" * }
            { t sortify * }
          if$
        }
        { t sortify * }
      if$
      nameptr #1 + 'nameptr :=
      namesleft #1 - 'namesleft :=
    }
  while$
}

FUNCTION {name.sort.key}
{ author empty$
    { editor empty$ not  editors.as.authors  and
        { editor sort.format.names }
        { org.name empty$
            { key empty$
                { title field.or.null sort.format.title }
                { key sortify }
              if$
            }
            { "The " #4 org.name chop.word sortify }
          if$
        }
      if$
    }
    { author sort.format.names }
  if$
}

FUNCTION {presort}
{ calc.year
  calc.labels
  short.list "(" * year.label * 'label :=
  % suffix grouping: same citation label, ordered by title
  label sortify
  "    " *
  name.sort.key *
  "    " *
  year.sort *
  "    " *
  title field.or.null sort.format.title *
  #1 entry.max$ substring$
  'sort.key$ :=
}

ITERATE {presort}

SORT

STRINGS { last.label next.extra }
INTEGERS { last.extra.num }

FUNCTION {initialize.extra.label}
{ #0 int.to.chr$ 'last.label :=
  "" 'next.extra :=
  #0 'last.extra.num :=
}

FUNCTION {forward.pass}
{ last.label label =
    { last.extra.num #1 + 'last.extra.num :=
      last.extra.num int.to.chr$ 'extra.label :=
    }
    { "a" chr.to.int$ 'last.extra.num :=
      "" 'extra.label :=
      label 'last.label :=
    }
  if$
}

FUNCTION {reverse.pass}
{ next.extra "b" =
    { "a" 'extra.label := }
    'skip$
  if$
  extra.label 'next.extra :=
  extra.label empty$
    'skip$
    { "\natexlab{" extra.label * "}" * 'extra.label := }
  if$
}

EXECUTE {initialize.extra.label}

ITERATE {forward.pass}

REVERSE {reverse.pass}

% Reference-list order: names, then year, then title.
FUNCTION {bib.sort.order}
{ name.sort.key
  "    " *
  year.sort *
  "    " *
  title field.or.null sort.format.title *
  #1 entry.max$ substring$
  'sort.key$ :=
}

ITERATE {bib.sort.order}

SORT

FUNCTION {begin.bib}
{ preamble$ empty$
    'skip$
    { preamble$ write$ newline$ }
  if$
  "\begin{thebibliography}{xx}" write$ newline$
  "\providecommand{\natexlab}[1]{#1}" write$ newline$
  "\providecommand{\url}[1]{\texttt{\detokenize{#1}}}" write$ newline$
  "\providecommand{\apsadoi}[1]{doi:~\ifdefined\href\href{https://doi.org/#1}{\nolinkurl{#1}}\else\url{#1}\fi}" write$ newline$
  "\providecommand{\apsapubdoi}[1]{\apsadoi{#1}.}" write$ newline$
  "\expandafter\ifx\csname urlstyle\endcsname\relax\else\urlstyle{same}\fi" write$ newline$
}

EXECUTE {begin.bib}

ITERATE {call.type$}

FUNCTION {end.bib}
{ newline$
  "\end{thebibliography}" write$ newline$
}

EXECUTE {end.bib}
