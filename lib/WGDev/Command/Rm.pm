package WGDev::Command::Rm;
# ABSTRACT: Remove WebGUI assets
use strict;
use warnings;
use 5.008008;

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub config_options {
    return qw(
        recursive|r
        tree=s@
        class=s@
    );
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my @assetHints = ( $self->arguments );

    if ( !@assetHints ) {
        WGDev::X->throw('No assets to edit!');
    }

    my $recursive   = $self->option('recursive'); #? 'descendants' : 'children';
    #my $force       = $self->option('force') || undef;

    my $error;
    while ( my $assetHint = shift @assetHints ) {
        my $asset;
        if ( !eval { $asset = $wgd->asset->find($assetHint) } ) {
            warn "wgd rm: $assetHint: No such asset\n";
            $error++;
            next;
        }
        
        $self->remove_asset( $asset, $recursive );
    }
    return (! $error);
}

sub remove_asset {
    my ($self, $asset, $recursive) = @_;
    my $wgd  = $self->wgd;
    print "Removing " . $asset->getId . "  -- " . $asset->getName . " -- '" . $asset->getTitle . "'...\n";
    my $childCount = $asset->getChildCount( { } );
    if( $childCount && $recursive ) {
        
        print "Removing descendants of " . $asset->getName . "\n";
        my $assets = $asset->getLineage( [qw(descendants)], {} );
        for my $asset_id ( @{ $assets } ) {
            $self->remove_asset( $wgd->asset->find( $asset_id ), $recursive );
        }
    }
        
    if( $childCount && !$recursive ) {
        print "Can not remove the " . $asset->getName . " '" . $asset->getTitle . "' because it has descendants!  (specify --recursive)\n";
    } else {
        #if (! ($asset->canEdit && $asset->canEditIfLocked) ) {
        #    print "You cannot edit the asset %s, skipping $assetId";
        #    $pb->update(sprintf $i18n->get('You cannot edit the acd sset %s, skipping'), $asset->getTitle);
        #}
        #else {
        $asset->trash( { outputSub => sub {
            my $message = shift;
            print $asset->getName . " '" . $asset->getTitle . "' => $message\n" if $message;
        } } );
        #}
    }
}

sub get_asset_list {
    my $self = shift;
    my $wgd  = $self->wgd;
    my @files;
    for my $asset_spec ( $self->arguments ) {
        my $file_data = eval { $self->write_temp($asset_spec) };
        if ( !$file_data ) {
            warn $@;
            next;
        }
        push @files, $file_data;
    }
    if ( $self->option('tree') ) {
        for my $parent_spec ( @{ $self->option('tree') } ) {
            my $parent = $wgd->asset->find($parent_spec) || do {
                warn "$parent_spec is not a valid asset!\n";
                next;
            };
            my $options = {};
            if ( $self->option('class') ) {
                my @classes = @{ $self->option('class') };
                for (@classes) {
                    s/^(?:(?:WebGUI::Asset)?::)?/WebGUI::Asset::/msx;
                }
                $options->{includeOnlyClasses} = \@classes;
            }
            my $assets
                = $parent->getLineage( [qw(self descendants)], $options );
            for my $asset_id ( @{$assets} ) {
                my $file_data = $self->write_temp($asset_id);
                if ( !$file_data ) {
                    next;
                }
                push @files, $file_data;
            }
        }
    }
    return @files;
}


1;

=head1 SYNOPSIS

    wgd rm [-r] [-f] <asset> [<asset> ...]

=head1 DESCRIPTION

Removes WebGUI assets

=head1 OPTIONS

=over 8

=item C<-r> C<--recurse>

Recurse 

=item C<-f> C<--force>

Force, is not current supported or needed, I think, since wildcards are not supported, yet.

=cut

