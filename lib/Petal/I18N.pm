# ------------------------------------------------------------------
# Petal::I18N - Independant I18N processing
# ------------------------------------------------------------------
package Petal::I18N;
use MKDoc::XML::TreeBuilder;
use MKDoc::XML::TreePrinter;
use Petal::Hash::String;
use warnings;
use strict;

our $Namespace = "http://xml.zope.org/namespaces/i18n";
our $Prefix    = 'i18n';
our $Domain    = 'default';


sub process
{
    my $class = shift;
    my $data  = shift;

    local $Namespace = $Namespace;
    local $Prefix    = $Prefix;
    local $Domain    = $Domain;

    my @nodes = MKDoc::XML::TreeBuilder->process_data ($data);
    for (@nodes) { $class->_process ($_) }
    return MKDoc::XML::TreePrinter->process (@nodes);
}


sub _process
{
    my $class = shift;
    my $tree  = shift;
    return unless (ref $tree);

    local $Prefix = $Prefix;
    local $Domain = $Domain;

    # process the I18N namespace
    foreach my $key (keys %{$tree})
    {
        my $value = $tree->{$key};
        if ($value eq $Namespace)
        {
            next unless ($key =~ /^xmlns\:/);
            delete $tree->{$key};
            $Prefix = $key;
            $Prefix =~ s/^xmlns\://;
        }
    }

    # set the current i18n:domain
    $Domain = delete $tree->{"$Prefix:domain"} || $Domain;

    my $tag  = $tree->{_tag};
    my $attr = { map { /^_/ ? () : ( $_ => $tree->{$_} ) } keys %{$tree} };
    return if ($tag eq '~comment' or $tag eq '~pi' or $tag eq '~declaration');


    # replace attributes with their respective translations 
    $tree->{"$Prefix:attributes"} && do {
        my $attributes = $tree->{"$Prefix:attributes"};
        $attributes =~ s/\s*;\s*$//;
        $attributes =~ s/^\s*//;
        my @attributes = split /\s*\;\s*/, $attributes;
        foreach my $attribute (@attributes)
        {
            # if we have i18n:attributes="alt alt_text", then the
            # attribute name is 'alt' and the
            # translate_id is 'alt_text'
            my ($attribute_name, $translate_id);
            if ($attribute =~ /\s/)
            {
                ($attribute_name, $translate_id) = split /\s+/, $attribute, 2;
            }

            # otherwise, if we have i18n:attributes="alt", then the
            # attribute name is 'alt' and the
            # translate_id is $tree->{'alt'}
            else
            {
                $attribute_name = $attribute;
                $translate_id = _canonicalize ( $tree->{$attribute_name} );
            }

            # the default value if maketext() fails should be the current
            # value of the attribute
            my $default_value = $tree->{$attribute_name};

            # the value to replace the attribute with should be either the
            # translation, or the default value if maketext() failed. 
            my $value = eval { $Petal::TranslationService->maketext ($translate_id) } || $default_value;

            # if maketext() failed, let's know why.
            $@ && warn $@;

            # set the (hopefully) translated value
            $tree->{$attribute_name} = $value;
        }
    };


    # replace content with its translation
    exists $tree->{"$Prefix:translate"} && do {
        my ($translate_id);

        # if we have $Domain:translate="something",
        # then the translate_id is 'something'
        if (defined $tree->{"$Prefix:translate"} and $tree->{"$Prefix:translate"} ne '')
        {
            $translate_id = $tree->{"$Prefix:translate"};
        }

        # otherwise, the translate_id has to be computed
        # from the contents of this node, so that
        # <div i18n:translate="">Hello, <span i18n:name="user">David</span>, how are you?</div>
        # becomes 'Hello, ${user}, how are you?'
        else
        {
            $translate_id = _canonicalize ( _extract_content_string ($tree) );
        }

        # the default value if maketext() fails should be the current
        # value of the attribute
        my $default_value = _canonicalize ( _extract_content_string ($tree) );

        # the value to replace the content with should be either the
        # translation, or the default value if maketext() failed. 
        my $value = eval { $Petal::TranslationService->maketext ($translate_id) } || $default_value;

        # now, $value is supposed to have the translated string, which looks like
        # 'Bonjour, ${user}, comment allez-vous?'. We need to turn this back into
        # a tree structure.
        my %named_nodes  = _extract_named_nodes ($tree);
        my @tokens       = @{Petal::Hash::String->_tokenize (\$value)};
        my @res = map {
        ($_ =~ /$Petal::Hash::String::TOKEN_RE/gsm) ?
            do {
                s/^\$//;
                s/^\{//;
                s/\}$//;
                $named_nodes{$_};
            } :
            do {
                s/\\(.)/$1/gsm;
                $_;
            };
        } @tokens;

        $tree->{_content} = \@res;
    };

    # I know, I know, the I18N namespace processing is a bit broken...
    # It should suffice for now.
    delete $tree->{"$Prefix:attributes"};
    delete $tree->{"$Prefix:translate"};
    delete $tree->{"$Prefix:name"};

    # Do the same i18n thing with child nodes, recursively.
    # for some reason it always makes me think of roller coasters.
    # Yeeeeeeee!
    defined $tree->{_content} and do {
        for (@{$tree->{_content}}) { $class->_process ($_) }
    };
}


sub _canonicalize
{
    my $string = shift;
    return '' unless (defined $string);

    $string =~ s/\s+/ /gsm;
    $string =~ s/^ //;
    $string =~ s/ $//;
    return $string;
}


sub _extract_named_nodes
{
    my $tree  = shift;
    my @nodes = ();
    foreach my $node (@{$tree->{_content}})
    {
        ref $node || next;
        push @nodes, $node;
    }
    
    my %nodes = ();
    my $count = 0;
    foreach my $node (@nodes)
    {
        $count++;
        my $name = $node->{"$Prefix:name"} || $count;
        $nodes{$name} = $node;
    }
    
    return %nodes;
}


sub _extract_content_string
{
    my $tree  = shift;
    my @res   = ();

    my $count = 0;
    foreach my $node (@{$tree->{_content}})
    {
        ref $node or do {
            push @res, $node;
            next;
        };
        
        $count++;
        my $name = $node->{"$Prefix:name"} || $count;
        push @res, '${' . $name . '}';
    }
    
    return join '', @res;
}


1;


__END__


=head1 NAME

Petal::I18N - Attempt at implementing ZPT I18N for Petal 


=head1 SYNOPSIS

in your Perl code:

  use Petal;
  use Petal::TranslationService::Gettext;

  my $translation_service = new Petal::TranslationService::Gettext (
      locale_dir  => '/path/to/my/app/locale',
      target_lang => gimme_target_lang(), 
  );

  my $template = new Petal (
      file => 'example.html',
      translation_service => $translation_service
  );

  # we want to internationalize to the h4x0rz 31337 l4nGu4g3z. w00t!
  my $translation_service = Petal::TranslationService::h4x0r->new();
  my $template = new Petal (
      file => 'silly_example.xhtml',
      translation_service => $ts,
  );

  print $template->process ();


=head1 I18N Howto


=head2 Preparing your templates:

Say your un-internationalized template looks like this:

  <html xmlns:tal="http://purl.org/petal/1.0/">
    <body>
      <img src="/images/my_logo.png"
           alt="the logo of our organisation" />

      <p>Hello,
         <span petal:content="user_name">Joe</span>.</p>

      <p>How are you today?</p>
    </body>
  </html>


You need to markup your template according to the ZPT I18N specification, which
can be found at
http://dev.zope.org/Wikis/DevSite/Projects/ComponentArchitecture/ZPTInternationalizationSupport

  <html xmlns:tal="http://purl.org/petal/1.0/"
        xmlns:i18n="http://xml.zope.org/namespaces/i18n"
        i18n:domain="my_app">
    <body>
      <img src="/images/my_logo.png"
           alt="the logo of our organisation"
           i18n:attributes="alt" />
      <p i18n:translate="">Hello, <span petal:content="user_name">Joe</span>.</p>
      <p i18n:translate="">How are you today?</p>
    </body>
  </html>


=head2 Extracting I18N strings:

Once your templates are marked up properly, you will need to use a tool to
extract the I18N strings into .pot (po template) files. To my knowledge you can
use i18ndude (standalone python executable), i18nextract.py (part of Zope 3),
or L<I18NFool>.

I use i18ndude to find strings which are not marked up properly with
i18n:translate attributes and I18NFool for extracting strings and managing .po
files.

Assuming you're using i18nfool:

  mkdir -p /path/to/my/app/locale
  cd /path/to/my/app/locale
  i18nfool-extract /path/to/my/template/example.html
  mkdir en
  mkdir fr
  mkdir es
  i18nfool-update

Then you translate the .po files into their respective target languages. When
that's done, you type:

  cd /path/to/my/app/locale
  i18nfool-build

And it builds all the .mo files.


=head2 Making your application use a Gettext translation service:

Previously you might have had:

  use Petal;
  # lotsa code here
  my $template = Petal->new ('example.html');

This needs to become:

  use Petal;
  use Petal::TranslationService::Gettext;
  # lotsa code here
  my $template = Petal->new ('example.html');
  $template->{translation_service} = Petal::TranslationService::Gettext->new (
      locale_dir  => '/path/to/my/app/locale',
      target_lang => gimme_language_code(),
  );

Where gimme_language_code() returns a language code depending on LC_LANG,
content-negotiation, config-file, or whatever mechanism you are using to decide
which language is desired.


=head2 And then?

And then that's it! Your application should be easily internationalizable.
There are a few traps / gotchas thought, which are described below.


=head1 BUGS, TRAPS, GOTCHAS and other niceties


=head2 Translation Phase

The translation step takes place ONLY ONCE THE TEMPLATE HAS BEEN PROCESSED.

So if you have:

  <p i18n:translate="">Hello,
    <span i18n:name="user_login" tal:replace="self/user_login">Joe</span>
  </p>

It most likely will not work because the tal:replace would remove the <span>
tag and also the i18n:name in the process.

This means that instead of receiving something such as:

  Hello, ${user_login}

The translation service would receive:

  Hello, Fred Flintstone

Or

  Hello, Joe SixPack

etc.

To fix this issue, use tal:content instead of tal:replace and leave the span
and its i18n:name attribute.


=head2 Character sets

I haven't worried too much about them (yet) so if you run into trouble join the
Petal mailing list and we'll try to fix any issues together.


=head2 Limitations

At the moment, L<Petal::I18N> supports the following constructs:

=over 4

=item xmlns:i18n="http://xml.zope.org/namespaces/i18n"

=item i18n:translate

=item i18n:domain

=item i18n:name

=item i18n:attribute

=back

It does *NOT* (well, not yet) support i18n:source, i18n:target or i18n:data.

=cut
