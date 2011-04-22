package WGDev::Command::God::Me;
# ABSTRACT: Sets an user session associated with an IP address to god mode (admin user).
use strict;
use warnings;
use 5.008008;

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

use WGDev ();

sub config_options {
    return qw(
    );
}

sub process {
    require File::Temp;
    
    my $self = shift;
    my $wgd  = $self->wgd;
    
    my $ip = join ".", $self->arguments;
    
    if ( !$ip ) {
        WGDev::X->throw('No IP to set!');
    }
        
    my ( $fh, $tempFile ) = File::Temp::tempfile();
    binmode $fh, ':utf8';
    print {$fh} "update userSession set userId='3' where lastIP = '$ip';";
    close $fh or return;
    
    eval {        
        my $db           = $self->wgd->db;
        my @command_line = ( $db->command_line( "< $tempFile" ) );
        my $call = "mysql " . join q/ / => @command_line ;
        system $call;
    };
    
    unlink $tempFile;
    
    if( !$@  ) {
        print "God-Me IP: $ip\n";
        return 1;
    }
    
    return 0;
}
1;

=head1 SYNOPSIS

    wgd god-me <ip>

=head1 DESCRIPTION

Sets all user sessions for a given IP to the admin user.  Use with care.

=head1 OPTIONS

=over 8

=item C<ip>

The IP for which all associated user sessions should be set to god-mode.

=cut

