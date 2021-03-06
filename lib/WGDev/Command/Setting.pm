package WGDev::Command::Setting;
# ABSTRACT: Returns WebGUI settings from the database.
use strict;
use warnings;
use 5.008008;

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub config_options {
    return qw();
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;
    my $dbh  = $wgd->db->connect;
    my $sth
        = $dbh->prepare('SELECT name, value FROM settings WHERE name LIKE ?');
    my $sth_set;
    foreach my $argument ( $self->arguments ) {
        my $new_value;
        if ( $argument =~ s/=(.*)//msx ) {
            $new_value = $1;
        }
        $sth->execute($argument);
        while ( my ( $setting, $value ) = $sth->fetchrow_array ) {
            if ( !defined $value ) {
                $value = '(NULL)';
            }
            if ( defined $new_value ) {
                $sth_set ||= $dbh->prepare(
                    'UPDATE settings SET value = ? WHERE name = ?');
                $sth_set->execute( $new_value, $setting );
                $sth_set->finish;
                printf "%-39s %s => %s\n", $setting, $value, $new_value;
            }
            else {
                printf "%-39s %s\n", $setting, $value;
            }
        }
    }

    return 1;
}

1;

=head1 SYNOPSIS

    wgd setting <setting>[=<value>] [<setting> ...]

=head1 DESCRIPTION

Prints settings from the WebGUI settings table.  This is handy for doing quick lookups,
or for using as part of other C<wgd> commands.  Can also the the value of settings.

=head1 OPTIONS

=over 8

=item C<< <setting> >>

The name of the setting to display.  Can also contain SQL wildcards
to show multiple settings.  Using a setting of C<%> will display
all settings.

=item C<< <value> >>

The value to set the setting to.  If specified, the old value and
new value will be included in the output.

=back

=cut

