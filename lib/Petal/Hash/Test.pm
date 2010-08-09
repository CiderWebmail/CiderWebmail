=head1 NAME

Petal::Hash::Test - Test and Tutorial Petal modifier

=head1 SUMMARY

Petal modifiers are snippets of code which are used to extend the
expression engine capabilities. This test shows how to write your
own modifiers.

=head1 API

The modifier API is very, very simple. It consists of two elements:

=head2 The package name

Your modifier should be called Petal::Hash::<SomeThing>, where <SomeThing>
is the name that you want to give to your modifier.

For example, this modifier is called Petal::Hash::Test. Petal will
automatically pick it the module up and assign it the 'test:' prefix.

    package Petal::Hash::Test;
    use warnings;
    use strict;

=cut
package Petal::Hash::Test;
use warnings;
use strict;


=head2 The method $class->process ($hash, $argument);

This class method will define the modifier in itself.

* $class is the package name of your modifier (which might come in
handy if you're subclassing a modifier),

* $hash is the execution context, i.e. the objects and data which
will 'fill' your template,

* $argument is whatever was after your modifier's prefix. For example,
for the expression 'test:foo bar', $argument would be 'foo bar'.

In this test / tutorial we're going to write a modifier which
uppercases a Petal expression.

  sub process
  {
      my $class    = shift;
      my $hash     = shift;
      my $argument = shift;
    
      return uc ($hash->get ($argument));
  }

  1;

  __END__

And that's it! Simple!

=cut
sub process
{
    my $class    = shift;
    my $hash     = shift;
    my $argument = shift;
    
    return uc ($hash->get ($argument));
}


1;


__END__


=head1 AUTHOR

Jean-Michel Hiver

This module is redistributed under the same license as Perl itself.

=head1 SEE ALSO

The template hash module:

  Petal::Hash

=cut
