package Petal::Utils::US_Date;

use strict;
use warnings::register;

use Carp;

use base qw( Petal::Utils::Base );

use constant name    => 'us_date';
use constant aliases => qw();

our $VERSION  = ((require Petal::Utils), $Petal::Utils::VERSION)[1];
our $REVISION = (split(/ /, ' $Revision: 1.2 $ '))[2];

sub process {
    my $class = shift;
    my $hash  = shift;
    my $args  = shift || confess( "'us_date' expects a variable (got nothing)!" );

    my ($year,$mon,$day);
    my ($date, $sep) = $hash->fetch($args);
    $sep ||= '/';
    if ($date =~ /[-|\/]/) {
	($year,$mon,$day) = split(/[-|\/]/, $date);
    }
    else {
	($year,$mon,$day) = $date =~ /(\d{4})(\d{2})(\d{2})/;
    }

    return sprintf("%02d$sep%02d$sep%04d", $mon,$day,$year);
}

1;

__END__

# Convert date from yyyy-mm-dd|yyyy/mm/dd|yyyymmdd to mm/dd/yyyy
# Arguments:
# 	$date - the date to be converted
# 	[$sep] - separator to use in new string (defaults to /)
