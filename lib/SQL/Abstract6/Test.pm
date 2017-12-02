unit module SQL::Abstract6::Test; # see doc at end of file
use v6;

use Test;
use SQL::Abstract::Tree:from<Perl5>;
use Inline::Perl5;

#   our @EXPORT_OK = qw(
#     is_same_sql_bind is_same_sql is_same_bind
#     eq_sql_bind eq_sql eq_bind dumper diag_where
#     $case_sensitive $sql_differ
#   );

my $sqlat = SQL::Abstract::Tree.new;

our $case_sensitive is export(:vars) = 0;
our $parenthesis_significant = 0;
our $order_by_asc_significant = 0;

our $sql_differ is export(:vars); # keeps track of differing portion between SQLs

#`<<
sub _unpack_arrayrefref {

  my @args;
  for (1,2) {
    my $chunk = shift @_;

    if (ref $chunk eq 'REF' and ref $$chunk eq 'ARRAY') {
      my ($sql, @bind) = @$$chunk;
      push @args, ($sql, \@bind);
    }
    else {
      push @args, $chunk, shift @_;
    }

  }

  # maybe $msg and ... stuff
  push @args, @_;

  @args;
}
>>

multi sub is_same_sql_bind(Capture $query1,
    Capture $query2,
    Str $msg) is export(:test) {
    die "Invalid arguments!"
        if not ( $query1.elems == 1 && $query2.elems == 1 )
            or $query1.hash.elems or $query2.hash.elems;
    is_same_sql_bind($query1[0][0], $query1[0][1],
        $query2[0][0], $query2[0][1], $msg);
}
multi sub is_same_sql_bind(Str $sql1, Array $bind_ref1,
    Str $sql2, Array $bind_ref2,
    Str $msg) is export(:test) {
  # compare
  my $same_sql  = eq_sql($sql1, $sql2);
  my $same_bind = eq_bind($bind_ref1, $bind_ref2);

  my $ret = ok($same_sql && $same_bind, $msg);

  # add debugging info
  if (!$same_sql) {
    _sql_differ_diag($sql1, $sql2);
  }
  if (!$same_bind) {
    _bind_differ_diag($bind_ref1, $bind_ref2);
  }

  # pass ok() result further
  return $ret;
}

sub is_same_sql($sql1, $sql2, $msg) is export(:test) {
  # compare
  my $same_sql = eq_sql($sql1, $sql2);

  my $ret = ok($same_sql, $msg);

  # add debugging info
  if (!$same_sql) {
    _sql_differ_diag($sql1, $sql2);
  }

  # pass ok() result further
  return $ret;
}

sub is_same_bind($bind_ref1, $bind_ref2, $msg) is export(:test) {
  # compare
  my $same_bind = eq_bind($bind_ref1, $bind_ref2);

  my $ret = ok($same_bind, $msg);

  # add debugging info
  if (!$same_bind) {
    _bind_differ_diag($bind_ref1, $bind_ref2);
  }

  # pass ok() result further
  return $ret;
}

sub dumper is export(:dumper) {
  # FIXME
  # if we save the instance, we will end up with $VARx references
  # no time to figure out how to avoid this (Deepcopy is *not* an option)
# require Data::Dumper;
# Data::Dumper->new([])->Terse(1)->Indent(1)->Useqq(1)->Deparse(1)->Quotekeys(0)->Sortkeys(1)->Maxdepth(0)
#   ->Values([@_])->Dump;
  [@_].perl;
}

sub diag_where is export(:test) {
  diag( "Search term:\n" . dumper(@_) );
}

sub _sql_differ_diag($sql1 = '', $sql2 = '') {
# $tb->${\($tb->in_todo ? 'note' : 'diag')} (
    diag(
       "SQL expressions differ\n"
      ~" got: $sql1\n"
      ~"want: $sql2\n"
      ~"\nmismatch around\n$sql_differ\n"
  );
}

sub _bind_differ_diag($bind_ref1, $bind_ref2) {
# $tb->${\($tb->in_todo ? 'note' : 'diag')} (
  diag(
    "BIND values differ " . dumper({ got => $bind_ref1, want => $bind_ref2 })
  );
}

multi sub eq_sql_bind(Capture $query1, Capture $query2) is export(:test) {
    die "Invalid arguments!"
        if not ( $query1.elems == 1 && $query2.elems == 1 )
            or $query1.hash.elems or $query2.hash.elems;
  return eq_sql_bind($query1[0][0], $query1[0][1], $query2[0][0], $query2[0][1]);
}
multi sub eq_sql_bind(Str $sql1, Array $bind_ref1, Str $sql2, Array $bind_ref2) is export(:test) {
  return eq_sql($sql1, $sql2) && eq_bind($bind_ref1, $bind_ref2);
}


sub eq_bind($left, $right)  is export(:test) {
    $left eqv $right;
};

sub debug(*@msg) {
    if (%*ENV<SQL_ABS_DEBUG>) {
        note |@msg;
    }
}

sub eq_sql is export(:test) {
  my ($sql1, $sql2) = @_;

  debug 'eq_sql[0]: ' ~ $sql1.perl;
  debug 'eq_sql[1]: ' ~ $sql2.perl;

  # parse
  my $tree1 = $sqlat.parse($sql1);
  my $tree2 = $sqlat.parse($sql2);
  debug $tree1.perl;
  debug $tree2.perl;

  $sql_differ = Nil;
  return 1 if _eq_sql($tree1, $tree2);
}

sub _eq_sql ($left, $right) {
  debug '_eq_sql';
  debug 'Left - ' ~ $left.perl;
  debug 'Right- ' ~ $right.perl;

  # one is defined the other not
  if ((defined $left) xor (defined $right)) {
    $sql_differ = sprintf("[%s] != [%s]\n", map { defined $_ ?? $sqlat.unparse($_) !! 'N/A' }, $left, $right );
    return 0;
  }

  # one is undefined, then so is the other
  elsif (not defined $left) {
    return 1;
  }

  # both are empty
  elsif ($left.Array.elems == 0 and $right.Array.elems == 0) {
    return 1;
  }

  subset P5List of Inline::Perl5::Array;
  # one is empty
  debug "Left("~$left.elems~") Right("~$right.elems~")";
  if ($left.Array.elems == 0 or $right.Array.elems == 0) {
    $sql_differ = sprintf("left: %s\nright: %s\n", map { .elems ?? $sqlat.unparse($_) !! 'N/A'}, $left, $right );
    return 0;
  }

  # one is a list, the other is an op with a list
  elsif ($left[0] ~~ P5List xor $right[0] ~~ P5List) {
    debug 'List / OP-List:'
        and dd ($left, $right);
    $sql_differ = sprintf("[%s] != [%s]\nleft: %s\nright: %s\n", map
      { $_ ~~ P5List ?? $sqlat.unparse($_) !! $_ },
      $left[0], $right[0], $left, $right
    );
    debug 'Difference computed';
    return 0;
  }

  # both are lists
  elsif ($left[0] ~~ P5List) {
    debug 'Both lists';
    loop (my $i = 0; $i <= $left.end or $i <= $right.end; $i++ ) {
      debug $left[$i].perl;
      debug $right[$i].perl;
      if (not _eq_sql($left[$i], $right[$i]) ) {
        if (! $sql_differ or $sql_differ !~~ / left \: \s .+ right \: \s /) {
          $sql_differ ||= '';
          $sql_differ ~= "\n" unless $sql_differ ~~ / \n $/ ;
          $sql_differ ~= sprintf("left: %s\nright: %s\n", map { $sqlat.unparse($_) }, $left, $right );
        }
        return 0;
      }
    }
    return 1;
  }

  # both are ops
  else {

    # unroll parenthesis if possible/allowed
    unless ($parenthesis_significant) {
      $sqlat._parenthesis_unroll($_) for $left, $right;
    }

    # unroll ASC order by's
    unless ($order_by_asc_significant) {
      $sqlat._strip_asc_from_order_by($_) for $left, $right;
    }

    if ($left[0] ne $right[0]) {
      debug 'Both ops:';
      $sql_differ = sprintf "OP [%s] != [%s] in\nleft: %s\nright: %s\n",
        $left[0].item,
        $right[0].item,
        $sqlat.unparse($left),
        $sqlat.unparse($right)
      ;
      debug 'Difference computed';
      return 0;
    }

    # literals have a different arg-sig
    elsif ($left[0] eq '-LITERAL') {
      (my $l = ' '~$left[1][0]~' ' ) ~~ s:g/\s+/ /;
      (my $r = ' '~$right[1][0]~' ') ~~ s:g/\s+/ /;
      my $eq = $case_sensitive ?? $l eq $r !! uc($l) eq uc($r);
      $sql_differ = "[$l] != [$r]\n" if not $eq;
      return $eq;
    }

    # if operators are identical, compare operands
    else {
      debug 'Same op:';
      debug 'Left  operand: ' ~ $left[1].perl;
      debug 'Right operand: ' ~ $right[1].perl;
      my $eq = _eq_sql($left[1], $right[1]);
      $sql_differ ||= sprintf("left: %s\nright: %s\n", map { $sqlat.unparse($_) }, ($left, $right) ) if not $eq;
      return $eq;
    }
  }
}

our sub parse { $sqlat.parse(@_) }

=finish

=head1 NAME

SQL::Abstract::Test - Helper function for testing SQL::Abstract

=head1 SYNOPSIS

  use v6;
  use SQL::Abstract6;
  use Test;
  use SQL::Abstract::Test import => [qw/
    is_same_sql_bind is_same_sql is_same_bind
    eq_sql_bind eq_sql eq_bind
  /];

  my ($sql, @bind) = SQL::Abstract.new.select(%args);

  is_same_sql_bind($given_sql,    \@given_bind,
                   $expected_sql, \@expected_bind, $test_msg);

  is_same_sql($given_sql, $expected_sql, $test_msg);
  is_same_bind(\@given_bind, \@expected_bind, $test_msg);

  my $is_same = eq_sql_bind($given_sql,    \@given_bind,
                            $expected_sql, \@expected_bind);

  my $sql_same = eq_sql($given_sql, $expected_sql);
  my $bind_same = eq_bind(\@given_bind, \@expected_bind);

=head1 DESCRIPTION

This module is only intended for authors of tests on
L<SQL::Abstract|SQL::Abstract> and related modules;
it exports functions for comparing two SQL statements
and their bound values.

The SQL comparison is performed on I<abstract syntax>,
ignoring differences in spaces or in levels of parentheses.
Therefore the tests will pass as long as the semantics
is preserved, even if the surface syntax has changed.

B<Disclaimer> : the semantic equivalence handling is pretty limited.
A lot of effort goes into distinguishing significant from
non-significant parenthesis, including AND/OR operator associativity.
Currently this module does not support commutativity and more
intelligent transformations like L<De Morgan's laws
|http://en.wikipedia.org/wiki/De_Morgan's_laws>, etc.

For a good overview of what this test framework is currently capable of refer
to C<t/10test.t>

=head1 FUNCTIONS

=head2 is_same_sql_bind

  is_same_sql_bind(
    $given_sql, @given_bind,
    $expected_sql, @expected_bind,
    $test_msg
  );

  is_same_sql_bind(
    [$given_sql, @given_bind],
    [$expected_sql, @expected_bind],
    $test_msg
  );

  is_same_sql_bind(
    $dbi6_rs.as_query
    [$expected_sql, @expected_bind],
    $test_msg
  );

Compares given and expected pairs of C<($sql, \@bind)> by unpacking C<@_>
as shown in the examples above and passing the arguments to L</eq_sql> and
L</eq_bind>. Calls L<Test::Builder/ok> with the combined result, with
C<$test_msg> as message.
If the test fails, a detailed diagnostic is printed.

=head2 is_same_sql

  is_same_sql(
    $given_sql,
    $expected_sql,
    $test_msg
  );

Compares given and expected SQL statements via L</eq_sql>, and calls
L<Test::Builder/ok> on the result, with C<$test_msg> as message.
If the test fails, a detailed diagnostic is printed.

=head2 is_same_bind

  is_same_bind(
    \@given_bind,
    \@expected_bind,
    $test_msg
  );

Compares given and expected bind values via L</eq_bind>, and calls
L<Test::Builder/ok> on the result, with C<$test_msg> as message.
If the test fails, a detailed diagnostic is printed.

=head2 eq_sql_bind

  my $is_same = eq_sql_bind(
    $given_sql, @given_bind,
    $expected_sql, @expected_bind,
  );

  my $is_same = eq_sql_bind(
    [$given_sql, @given_bind],
    [$expected_sql, @expected_bind],
  );

  my $is_same = eq_sql_bind(
    $dbi6_rs.as_query
    [ $expected_sql, @expected_bind ],
  );

Unpacks C<@_> depending on the given arguments and calls L</eq_sql> and
L</eq_bind>, returning their combined result.

=head2 eq_sql

  my $is_same = eq_sql($given_sql, $expected_sql);

Compares the abstract syntax of two SQL statements. Similar to L</is_same_sql>,
but it just returns a boolean value and does not print diagnostics.
If the result is false, the global variable L</$sql_differ>
will contain the SQL portion where a difference was encountered; this is useful
for printing diagnostics.

=head2 eq_bind

  my $is_same = eq_sql(@given_bind, @expected_bind);

Compares two lists of bind values, taking into account the fact that some of
the values may be arrayrefs (see L<SQL::Abstract/bindtype>). Similar to
L</is_same_bind>, but it just returns a boolean value and does not print
diagnostics or talk to L<Test::Builder>.

=head1 GLOBAL VARIABLES

=head2 $case_sensitive

If true, SQL comparisons will be case-sensitive. Default is false;

=head2 $parenthesis_significant

If true, SQL comparison will preserve and report difference in nested
parenthesis. Useful while testing C<IN (( x ))> vs C<IN ( x )>.
Defaults to false;

=head2 $order_by_asc_significant

If true SQL comparison will consider C<ORDER BY foo ASC> and
C<ORDER BY foo> to be different. Default is false;

=head2 $sql_differ

When L</eq_sql> returns false, the global variable
C<$sql_differ> contains the SQL portion
where a difference was encountered.

=head1 SEE ALSO

L<SQL::Abstract>, L<Test::More>, L<Test::Builder>.

=head1 AUTHORS

Laurent Dami <laurent.dami AT etat  geneve  ch>

Norbert Buchmuller <norbi@nix.hu>

Peter Rabbitson <ribasushi@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Laurent Dami.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
# vim: set syntax=perl6:
