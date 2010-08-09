package Petal::Hash;
use strict;
use warnings;
use Carp;

our $MODIFIERS = {};

# import all plugins once
foreach my $include_dir (@INC)
{
    my $dir = "$include_dir/Petal/Hash";
    if (-e $dir and -d $dir)
    {
	opendir DD, $dir or do {
	    warn "Cannot open directory $dir. Reason: $!";
	    next;
	};
	
	my @modules = map { s/\.pm$//; $_ }
	              grep /\.pm$/,
		      grep !/^\./,
		      readdir (DD);
	
	closedir DD;
	
	foreach my $module (@modules)
	{
		$module =~ /^(\w+)$/;
		$module = $1;
		eval "use Petal::Hash::$module";
	    $@ and warn "Cannot import module $module. Reason: $@";
	    $MODIFIERS->{lc ($module) . ':'} = "Petal::Hash::$module";
	}
    }
}


# set modifier
$MODIFIERS->{'set:'} = sub {
    my $hash  = shift;
    my $argument = shift;
    my @split = split /\s+/, $argument;
    my $set   = shift (@split) or confess "bad syntax for 'set:': $argument (\$set)";
    my $value = $hash->fetch (join ' ', @split);
    $hash->{$set} = $value;
    delete $hash->{__petal_hash_cache__}->{$set};
    return '';
};
$MODIFIERS->{'def:'}    = $MODIFIERS->{'set:'};
$MODIFIERS->{'define:'} = $MODIFIERS->{'set:'};


# true modifier
$MODIFIERS->{'true:'} = sub {
    my $hash = shift;
    my $variable = $hash->fetch (@_);
    return unless (defined $variable);
    
    (scalar @{$variable}) ? return 1 : return
        if (ref $variable eq 'ARRAY' or (ref $variable and $variable =~ /=ARRAY\(/));
    
    ($variable) ? return 1 : return;
};


# false modifier
$MODIFIERS->{'false:'} = sub {
    my $hash = shift;
    my $variable = join ' ', @_;
    return not $hash->fetch ("true:$variable");
};

$MODIFIERS->{'not:'} = $MODIFIERS->{'false:'};

# encode: modifier (deprecated stuff)
$MODIFIERS->{'encode:'} = sub {
    warn "Petal modifier encode: is deprecated";
    my $hash = shift;
    my $argument = shift;
    return $hash->fetch ($argument);
};
$MODIFIERS->{'xml:'}         = $MODIFIERS->{'encode:'};
$MODIFIERS->{'html:'}        = $MODIFIERS->{'encode:'};
$MODIFIERS->{'encode_html:'} = $MODIFIERS->{'encode:'};


# Instanciates a new Petal::Hash object which should
# be tied to a hash.
sub new
{
    my $thing = shift;
    my $self  = (ref $thing) ?
        bless { %{$thing} }, ref $thing :
	bless { @_ }, $thing;
    
    $self->{__petal_hash_cache__}  = {};
    return $self;
}


# Gets a value...
sub get
{
    my $self   = shift;
    my $key    = shift;
    my $fresh  = $key =~ s/^\s*fresh\s+//;
    delete $self->{__petal_hash_cache__}->{$key} if ($fresh);
    exists $self->{__petal_hash_cache__}->{$key} and return $self->{__petal_hash_cache__}->{$key};

    my $res = undef;   
    if ($Petal::HTML_ERRORS)
    {
        $res = eval { $self->__FETCH ($key) };
        $@ and return "[ Cannot fetch $key. <!-- $@ --> ]";
    }
    else
    {
        $res = $self->__FETCH ($key);
    }

    $self->{__petal_hash_cache__}->{$key} = $res;
    return $res;
}


sub get_encoded
{
    my $self = shift;
    my $key  = shift;
    my $res  = $self->get ($key);
    return unless (defined $res);

    my $no_encode = $key =~ s/^\s*structure\s+//;
    unless ($no_encode and $no_encode)
    {
        $res =~ s/\&/\&amp;/g;
        $res =~ s/\</\&lt;/g;
        $res =~ s/\"/\&quot;/g;
    }

    return $res;
}


sub delete_cached
{
    my $self  = shift;
    my $regex = shift;
    for (keys %{$self->{__petal_hash_cache__}})
    {
	/$regex/ and delete $self->{__petal_hash_cache__}->{$_};
    }
}


sub __FETCH
{
    my $self = shift;
    my $key  = shift;
    my $no_encode = $key =~ s/^\s*structure\s+//;
    if (defined $no_encode and $no_encode)
    {
	return $self->fetch ($key);
    }
    else
    {
        # can anyone explain why keys beginning with 'text' are not allowed???
	$key =~ s/^\s*text\s*//;
	return $self->fetch ($key);
    }
}


# this method fetches a Petal expression and returns it
# without XML encoding. FETCH is basically a wrapper around
# fetch() which looks for the special keyword 'structure'.
sub fetch
{
    my $self = shift;
    my $key  = shift;
    
    my $mod  = $self->_fetch_mod ($key);
    $key =~ s/^\Q$mod\E//;
    $key =~ s/^\s+//;
    
    my $module = $MODIFIERS->{$mod} || confess "$mod is not a known modifier";
    (defined $module and ref $module and ref $module eq 'CODE') and return $module->($self, $key); 
    $module->process ($self, $key);
}


sub _fetch_mod
{
    my $self  = shift;
    my $key   = shift;
    my ($mod) = $key =~ /^([A-Za-z0-9_-]+?\:).*/;
    defined $mod || return 'var:';
    return $mod;
}


1;


__END__
