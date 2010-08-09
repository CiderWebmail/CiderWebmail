# Entirely stolen from HTML::Entities
# And modified to fit Petal's purposes.
package Petal::Entities;
use strict;
use warnings;


our %ENTITY_2_CHAR = (
 # Some normal chars that have special meaning in SGML context
 # those will be managed by XML::Parser
 # so we don't want to expand them
 # amp    => '&',  # ampersand 
 # 'gt'    => '>',  # greater than
 # 'lt'    => '<',  # less than
 # quot   => '"',  # double quote
 # apos   => "'",  # single quote
		      
 # PUBLIC ISO 8879-1986//ENTITIES Added Latin 1//EN//HTML
 AElig	=> 'Æ',  # capital AE diphthong (ligature)
 Aacute	=> 'Á',  # capital A, acute accent
 Acirc	=> 'Â',  # capital A, circumflex accent
 Agrave	=> 'À',  # capital A, grave accent
 Aring	=> 'Å',  # capital A, ring
 Atilde	=> 'Ã',  # capital A, tilde
 Auml	=> 'Ä',  # capital A, dieresis or umlaut mark
 Ccedil	=> 'Ç',  # capital C, cedilla
 ETH	=> 'Ð',  # capital Eth, Icelandic
 Eacute	=> 'É',  # capital E, acute accent
 Ecirc	=> 'Ê',  # capital E, circumflex accent
 Egrave	=> 'È',  # capital E, grave accent
 Euml	=> 'Ë',  # capital E, dieresis or umlaut mark
 Iacute	=> 'Í',  # capital I, acute accent
 Icirc	=> 'Î',  # capital I, circumflex accent
 Igrave	=> 'Ì',  # capital I, grave accent
 Iuml	=> 'Ï',  # capital I, dieresis or umlaut mark
 Ntilde	=> 'Ñ',  # capital N, tilde
 Oacute	=> 'Ó',  # capital O, acute accent
 Ocirc	=> 'Ô',  # capital O, circumflex accent
 Ograve	=> 'Ò',  # capital O, grave accent
 Oslash	=> 'Ø',  # capital O, slash
 Otilde	=> 'Õ',  # capital O, tilde
 Ouml	=> 'Ö',  # capital O, dieresis or umlaut mark
 THORN	=> 'Þ',  # capital THORN, Icelandic
 Uacute	=> 'Ú',  # capital U, acute accent
 Ucirc	=> 'Û',  # capital U, circumflex accent
 Ugrave	=> 'Ù',  # capital U, grave accent
 Uuml	=> 'Ü',  # capital U, dieresis or umlaut mark
 Yacute	=> 'Ý',  # capital Y, acute accent
 aacute	=> 'á',  # small a, acute accent
 acirc	=> 'â',  # small a, circumflex accent
 aelig	=> 'æ',  # small ae diphthong (ligature)
 agrave	=> 'à',  # small a, grave accent
 aring	=> 'å',  # small a, ring
 atilde	=> 'ã',  # small a, tilde
 auml	=> 'ä',  # small a, dieresis or umlaut mark
 ccedil	=> 'ç',  # small c, cedilla
 eacute	=> 'é',  # small e, acute accent
 ecirc	=> 'ê',  # small e, circumflex accent
 egrave	=> 'è',  # small e, grave accent
 eth	=> 'ð',  # small eth, Icelandic
 euml	=> 'ë',  # small e, dieresis or umlaut mark
 iacute	=> 'í',  # small i, acute accent
 icirc	=> 'î',  # small i, circumflex accent
 igrave	=> 'ì',  # small i, grave accent
 iuml	=> 'ï',  # small i, dieresis or umlaut mark
 ntilde	=> 'ñ',  # small n, tilde
 oacute	=> 'ó',  # small o, acute accent
 ocirc	=> 'ô',  # small o, circumflex accent
 ograve	=> 'ò',  # small o, grave accent
 oslash	=> 'ø',  # small o, slash
 otilde	=> 'õ',  # small o, tilde
 ouml	=> 'ö',  # small o, dieresis or umlaut mark
 szlig	=> 'ß',  # small sharp s, German (sz ligature)
 thorn	=> 'þ',  # small thorn, Icelandic
 uacute	=> 'ú',  # small u, acute accent
 ucirc	=> 'û',  # small u, circumflex accent
 ugrave	=> 'ù',  # small u, grave accent
 uuml	=> 'ü',  # small u, dieresis or umlaut mark
 yacute	=> 'ý',  # small y, acute accent
 yuml	=> 'ÿ',  # small y, dieresis or umlaut mark

 # Some extra Latin 1 chars that are listed in the HTML3.2 draft (21-May-96)
 copy   => '©',  # copyright sign
 reg    => '®',  # registered sign
 nbsp   => "\240", # non breaking space

 # Additional ISO-8859/1 entities listed in rfc1866 (section 14)
 iexcl  => '¡',
 cent   => '¢',
 pound  => '£',
 curren => '¤',
 yen    => '¥',
 brvbar => '¦',
 sect   => '§',
 uml    => '¨',
 ordf   => 'ª',
 laquo  => '«',
'not'   => '¬',    # not is a keyword in perl
 shy    => '­',
 macr   => '¯',
 deg    => '°',
 plusmn => '±',
 sup1   => '¹',
 sup2   => '²',
 sup3   => '³',
 acute  => '´',
 micro  => 'µ',
 para   => '¶',
 middot => '·',
 cedil  => '¸',
 ordm   => 'º',
 raquo  => '»',
 frac14 => '¼',
 frac12 => '½',
 frac34 => '¾',
 iquest => '¿',
'times' => '×',    # times is a keyword in perl
 divide => '÷',

 ( $] > 5.007 ? (
   OElig    => chr(338),
   oelig    => chr(339),
   Scaron   => chr(352),
   scaron   => chr(353),
   Yuml     => chr(376),
   fnof     => chr(402),
   circ     => chr(710),
   tilde    => chr(732),
   Alpha    => chr(913),
   Beta     => chr(914),
   Gamma    => chr(915),
   Delta    => chr(916),
   Epsilon  => chr(917),
   Zeta     => chr(918),
   Eta      => chr(919),
   Theta    => chr(920),
   Iota     => chr(921),
   Kappa    => chr(922),
   Lambda   => chr(923),
   Mu       => chr(924),
   Nu       => chr(925),
   Xi       => chr(926),
   Omicron  => chr(927),
   Pi       => chr(928),
   Rho      => chr(929),
   Sigma    => chr(931),
   Tau      => chr(932),
   Upsilon  => chr(933),
   Phi      => chr(934),
   Chi      => chr(935),
   Psi      => chr(936),
   Omega    => chr(937),
   alpha    => chr(945),
   beta     => chr(946),
   gamma    => chr(947),
   delta    => chr(948),
   epsilon  => chr(949),
   zeta     => chr(950),
   eta      => chr(951),
   theta    => chr(952),
   iota     => chr(953),
   kappa    => chr(954),
   lambda   => chr(955),
   mu       => chr(956),
   nu       => chr(957),
   xi       => chr(958),
   omicron  => chr(959),
   pi       => chr(960),
   rho      => chr(961),
   sigmaf   => chr(962),
   sigma    => chr(963),
   tau      => chr(964),
   upsilon  => chr(965),
   phi      => chr(966),
   chi      => chr(967),
   psi      => chr(968),
   omega    => chr(969),
   thetasym => chr(977),
   upsih    => chr(978),
   piv      => chr(982),
   ensp     => chr(8194),
   emsp     => chr(8195),
   thinsp   => chr(8201),
   zwnj     => chr(8204),
   zwj      => chr(8205),
   lrm      => chr(8206),
   rlm      => chr(8207),
   ndash    => chr(8211),
   mdash    => chr(8212),
   lsquo    => chr(8216),
   rsquo    => chr(8217),
   sbquo    => chr(8218),
   ldquo    => chr(8220),
   rdquo    => chr(8221),
   bdquo    => chr(8222),
   dagger   => chr(8224),
   Dagger   => chr(8225),
   bull     => chr(8226),
   hellip   => chr(8230),
   permil   => chr(8240),
   prime    => chr(8242),
   Prime    => chr(8243),
   lsaquo   => chr(8249),
   rsaquo   => chr(8250),
   oline    => chr(8254),
   frasl    => chr(8260),
   euro     => chr(8364),
   image    => chr(8465),
   weierp   => chr(8472),
   real     => chr(8476),
   trade    => chr(8482),
   alefsym  => chr(8501),
   larr     => chr(8592),
   uarr     => chr(8593),
   rarr     => chr(8594),
   darr     => chr(8595),
   harr     => chr(8596),
   crarr    => chr(8629),
   lArr     => chr(8656),
   uArr     => chr(8657),
   rArr     => chr(8658),
   dArr     => chr(8659),
   hArr     => chr(8660),
   forall   => chr(8704),
   part     => chr(8706),
   exist    => chr(8707),
   empty    => chr(8709),
   nabla    => chr(8711),
   isin     => chr(8712),
   notin    => chr(8713),
   ni       => chr(8715),
   prod     => chr(8719),
   sum      => chr(8721),
   minus    => chr(8722),
   lowast   => chr(8727),
   radic    => chr(8730),
   prop     => chr(8733),
   infin    => chr(8734),
   ang      => chr(8736),
  'and'     => chr(8743),
  'or'      => chr(8744),
   cap      => chr(8745),
   cup      => chr(8746),
  'int'     => chr(8747),
   there4   => chr(8756),
   sim      => chr(8764),
   cong     => chr(8773),
   asymp    => chr(8776),
  'ne'      => chr(8800),
   equiv    => chr(8801),
  'le'      => chr(8804),
  'ge'      => chr(8805),
  'sub'     => chr(8834),
   sup      => chr(8835),
   nsub     => chr(8836),
   sube     => chr(8838),
   supe     => chr(8839),
   oplus    => chr(8853),
   otimes   => chr(8855),
   perp     => chr(8869),
   sdot     => chr(8901),
   lceil    => chr(8968),
   rceil    => chr(8969),
   lfloor   => chr(8970),
   rfloor   => chr(8971),
   lang     => chr(9001),
   rang     => chr(9002),
   loz      => chr(9674),
   spades   => chr(9824),
   clubs    => chr(9827),
   hearts   => chr(9829),
   diams    => chr(9830),
 ) : ())
);


my %subst;  # compiled encoding regexps


sub decode_entities
{
    my $array = \@_;  # modify in-place
    
    my $c;
    for (@$array) {
	s/(&\#(\d+);?)/$2 < 256 ? chr($2) : $1/eg;
	s/(&\#[xX]([0-9a-fA-F]+);?)/$c = hex($2); $c < 256 ? chr($c) : $1/eg;
	s/(&(\w+);?)/$ENTITY_2_CHAR{$2} || $1/eg;
    }
    wantarray ? @$array : $array->[0];
}


1;
