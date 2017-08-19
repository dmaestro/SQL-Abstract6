unit module SQL;
use v6;

use Inline::Perl5;
use SQL::Abstract:from<Perl5>;

class Abstract6 {
    has $.case;
    has $.cmp           = '=';
    has $.sqltrue       = '1=1';
    has $.sqlfalse      = '1=0';
    has $.logic;
    has $.convert;
    has $.bindtype      = 'normal';
    has $.quote_char    = '';
    has $.escape_char;  # default is quote_char if single character,
                        # or the right quote if bracketing
    has $.name_sep      = '.';  # required if quote_char is used
    has $.injection_guard   = rx:i/ ";" | <|w> GO <|w>/;
    has $.array_datatypes   = False; # backward compat only
    has $.special_ops;
    has $.unary_ops;

    has $!sql_abstract;
    method !sql_abstract5() {
        if not $!sql_abstract.defined {
            $!sql_abstract = SQL::Abstract.new(
            );
        }
        $!sql_abstract;
    }
}
