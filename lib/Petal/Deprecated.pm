=head1 NAME

Petal::Deprecated - Documents Petal's deprecated syntax.


=head1 IMPORTANT NOTE 

This is an article, not a module.

From version 2.00 onwards Petal *requires* that you use well-formed XML. This
is because Petal now uses L<MKDoc::XML::TreeBuilder> rather than
L<HTML::TreeBuilder> and L<XML::Parser>.

In particular, this version of Petal *CAN* break backwards compatibility if you
were using Petal's HTML mode will non well formed XHTML.

If you still want to use broken XHTML, you can Petal 2.00 in conjunction with
L<Petal::Parser::HTB> which has been created for this purpose.


=head1 INLINE VARIABLES SYNTAX 

    <!--? This is a template comment.
          It will not appear in the output -->
    <html xmlns:tal="http://purl.org/petal/1.0/">
      <body>
        This is the variable 'my_var' : ${my_var}.
      </body>
    </html>

And if C<my_var> contained I<Hello World>, Petal would have outputted:

    <html>
      <body>
        This is the variable 'my_var' : Hello World.
      </body>
    </html>


Now let's say that C<my_var> is a hash reference as follows:

    $VAR1 = { hello_world => 'Hello, World' }


To output the same result, you would write:

    This is the variable 'my_var' : ${my_var/hello_world}.


=head1 SETTING PETAL OPTIONS AS GLOBALS 

If you want to use an option throughout your entire program and don't want to
have to pass it to the constructor each time, you can set them globally. They
will then act as defaults unless you override them in the constructor.

  $Petal::BASE_DIR           (use base_dir option)
  $Petal::INPUT              (use input option)
  $Petal::OUTPUT             (use output option)
  $Petal::TAINT              (use taint option)
  $Petal::ERROR_ON_UNDEF_VAR (use error_on_undef_var option)
  $Petal::DISK_CACHE         (use disk_cache option)
  $Petal::MEMORY_CACHE       (use memory_cache option)
  $Petal::MAX_INCLUDES       (use max_includes option)
  $Petal::LANGUAGE           (use default_language option)
  $Petal::DEBUG_DUMP         (use debug_dump option)
    # $Petal::ENCODE_CHARSET     (use encode_charset option) -- _DEPRECATED_
  $Petal::DECODE_CHARSET     (use decode_charset option)


=head1 TAL DIRECTIVES ALIASES

On top of all that, for people who are lazy at typing the following
aliases are provided (although I would recommend sticking to the
defaults):

  * tal:define     - tal:def, tal:set
  * tal:condition  - tal:if
  * tal:repeat     - tal:for, tal:loop, tal:foreach
  * tal:attributes - tal:att, tal:attr, tal:atts
  * tal:content    - tal:inner
  * tal:replace    - tal:outer


TRAP:

Don't forget that the default prefix is C<petal:> NOT C<tal:>, until
you set the petal namespace in your HTML or XML document as follows:

    <html xmlns:tal="http://purl.org/petal/1.0/">


=head1 XINCLUDES

Let's say that your base directory is C</templates>,
and you're editing C</templates/hello/index.html>.

From there you want to include C</templates/includes/header.html>


=head2 general syntax

You can use a subset of the XInclude syntax as follows:

  <body xmlns:xi="http://www.w3.org/2001/XInclude">
    <xi:include href="/includes/header.html" />
  </body>


For backwards compatibility reasons, you can omit the first slash, i.e.

  <xi:include href="includes/header.html" />


=head2 relative paths

If you'd rather use a path which is relative to the template itself rather
than the base directory, you can do it but the path MUST start with a dot,
i.e.

  <xi:include href="../includes/header.html" />

  <xi:include href="./subdirectory/foo.xml" />

etc.


=head2 limitations

The C<href> parameter does not support URIs, no other tag than C<xi:include> is
supported, and no other directive than the C<href> parameter is supported at
the moment.

Also note that contrarily to the XInclude specification Petal DOES allow
recursive includes up to C<$Petal::MAX_INCLUDES>. This behavior is very useful
when templating structures which fit well recursive processing such as trees,
nested lists, etc.

You can ONLY use the following Petal directives with Xinclude tags:

  * on-error
  * define
  * condition
  * repeat

C<replace>, C<content>, C<omit-tag> and C<attributes> are NOT supported in
conjunction with XIncludes.


=head1 UGLY SYNTAX

For certain things which are not doable using TAL you can use what
I call the UGLY SYNTAX. The UGLY SYNTAX is UGLY, but it can be handy
in some cases.

For example consider that you have a list of strings:

    $my_var = [ 'Foo', 'Bar', 'Baz' ];
    $template->process (my_var => $my_var, buz => $buz);


And you want to display:

  <title>Hello : Foo : Bar : Baz</title>

Which is not doable with TAL without making the XHTML invalid.
With the UGLY SYNTAX you can do:

    <title>Hello<?for name="string my_var"?> : <?var name="string"?><?end?></title>

Of course you can freely mix the UGLY SYNTAX with other Petal
syntaxes. So:

    <title><?for name="string my_var"?> $string <?end?></title>

Mind you, if you've managed to read the doc this far I must confess
that writing:

    <h1>$string</h1>

instead of:

    <h1 tal:replace="string">Dummy</h1>

is UGLY too. I would recommend to stick with TAL wherever you can.
But let's not disgress too much.


=head2 variables

Abstract

  <?var name="EXPRESSION"?>

Example

  <title><?var name="document/title"?></title>

Why?

Because if you don't have things which are replaced by real values in your
template, it's probably a static page, not a template... :) 


=head2 if / else constructs

Usual stuff:

  <?if name="user/is_birthay"?>
    Happy Birthday, $user/real_name!
  <?else?>
    What?! It's not your birthday?
    A very merry unbirthday to you! 
  <?end?>

You can use C<condition> instead of C<if>, and indeed you can use modifiers:

  <?condition name="false:user/is_birthay"?>
    What?! It's not your birthday?
    A very merry unbirthday to you! 
  <?else?>
    Happy Birthday, $user/real_name!
  <?end?>

Not much else to say!


=head2 loops

Use either C<for>, C<foreach>, C<loop> or C<repeat>. They're all the same
thing, which one you use is a matter of taste. Again no surprise:

  <h1>Listing of user logins</h1>
  <ul>
    <?repeat name="user system/list_users"?>
      <li><?var name="user/login"?> :
          <?var name="user/real_name"?></li>
    <?end?>
  </ul>
  

Variables are scoped inside loops so you don't risk to erase an existing
C<user> variable which would be outside the loop. The template engine also
provides the following variables for you inside the loop:

  <?repeat name="foo bar"?>
    <?var name="repeat/index"?>  - iteration number, starting at 0
    <?var name="repeat/number"?> - iteration number, starting at 1
    <?var name="repeat/start"?>  - is it the first iteration?
    <?var name="repeat/end"?>    - is it the last iteration?
    <?var name="repeat/inner"?>  - is it not the first and not the last iteration?
    <?var name="repeat/even"?>   - is the count even?
    <?var name="repeat/odd"?>    - is the count odd?
  <?end?>

Again these variables are scoped, you can safely nest loops, ifs etc...  as
much as you like and everything should be fine.


=head2 Includes 

  <?include file="include.xml"?>

It will include the file 'include.xml', using the current C<@Petal::BASE_DIR>
directory list.

If you want use XML::Parser to include files, you should make sure that
the included files are valid XML themselves... FYI XML::Parser chokes on
this:

    <p>foo</p>
    <p>bar</p>

But this works:

    <div>
      <p>foo</p>
      <p>bar</p>
    </div>

(Having only one top element is part of the XML spec).


=cut
