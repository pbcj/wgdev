package WGDev::Command::Cp;
# ABSTRACT: Copy WebGUI asset(s)
use strict;
use warnings;
use 5.008008;

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub config_options {
    return qw(
        recursive|r
        notimpl-by-url|u
        in-base-url|b
        notimpl-excludeClass=s@
        notimpl-includeOnlyClass=s@
        notimpl-limit=n
        notimpl-isa=s
        notimpl-filter=s
    );
}


sub option_filter {
    my $self   = shift;
    my $filter = shift;

    my ( $filter_prop, $filter_sense, $filter_match )
        = $filter =~ m{%(\w+)% \s* ([~!])~ \s* (.*)}msx;
    if (   !defined $filter_prop
        || !defined $filter_sense
        || !defined $filter_match )
    {
        WGDev::X->throw("Invalid filter specified: $filter");
    }
    if ( $filter_match =~ m{\A/(.*)/\Z}msx ) {
        eval { $filter_match = qr/$1/msx; }
            || WGDev::X->throw(
            "Specified filter is not a valid regular expression: $1");
    }
    else {
        $filter_match = qr/\A\Q$filter_match\E\z/msx;
    }
    $self->{filter_property} = $filter_prop;
    $self->{filter_sense}    = $filter_sense eq q{~};
    $self->{filter_match}    = $filter_match;
    return;
}

sub process {
    my $self = shift;
    my $wgd  = $self->wgd;

    my $relatives   = $self->option('recursive') ? 'children' : 'self';
    my ($fromAssetHint,$toUrl,$inParentHint) = $self->arguments;
    #my $exclude_classes      = $self->option('excludeClass');
    #my $include_only_classes = $self->option('includeOnlyClass');
    #my $limit                = $self->option('limit');
    #my $isa                  = $self->option('isa');
    my $stayInBaseUrl        = $self->option('in-base-url');
    my $recursive            = $self->option('recursive');
    #my $byUrlOnly            = $self->option('by-url');

    my $error;
    
    my $asset;
    if ( !eval { $asset = $wgd->asset->find($fromAssetHint) } ) {
        warn "wgd cp: $fromAssetHint: No such asset\n";
        return;
    }
    
    my $parent;
    eval {
        $parent = defined $inParentHint ? $wgd->asset->find( $inParentHint ) : $asset->getParent;
    };
    $error++ if $@;
  
    die "Specified parent was not found: $inParentHint" if !defined $parent;
    
    my $versionTag = WebGUI::VersionTag->create(
        $wgd->session,
        { groupToUse => 3, name => "wgd cp $fromAssetHint $toUrl" . defined $inParentHint ? $inParentHint : '' }
    );
    
    $versionTag->setWorking;
    
    # Copy asset
    my $copy = $asset->duplicate(
        {   skipAutoCommitWorkflows => 0,
            skipNotification        => 1
        }
    );
    
    # Move under new parent or rename 
    if( defined $inParentHint && $parent != $copy->getParent ) {
        $copy->setParent( $parent ) if defined $inParentHint;
    } else {
        my $newTitle = $copy->get( 'title' ) . " ($toUrl)";
        $copy->update( { menuTitle => $newTitle, title => $newTitle } );
    }
    
    # Change URL
    my $fromUrl = $asset->get( 'url' );
    $copy->update( { url => $toUrl } );
    
    # Recurse
    $self->copyChildren( $asset, $copy, $fromUrl, $toUrl, $stayInBaseUrl ) if $recursive;
    
    $versionTag->commit;
    return 1;    
    #return (! $error);
}

sub copyChildren {
    my ( $self, $asset, $toParent, $fromUrl, $toUrl, $stayInBaseUrl ) = @_;
    print 'copying /' , $asset->get( 'url' ) , "\n";
    my $children = $asset->getLineage( [ qw( children ) ], { returnObjects => 1 } );
    for my $child ( @$children ) {
        next if $stayInBaseUrl && !( $child->get( 'url' ) =~ m/$fromUrl/ );
        my $copy = $child->duplicate(
            {   skipAutoCommitWorkflows => 0,
                skipNotification        => 1
            }
        );
        my $newUrl = $child->get( 'url' );
        $newUrl =~ s/^$fromUrl/$toUrl/;
        $copy->setParent( $toParent );
        $copy->update( { url => $newUrl } );
        $self->copyChildren( $child, $copy, $fromUrl, $toUrl, $stayInBaseUrl ) if $child->hasChildren;
    }
}

sub pass_filter {
    my ( $self, $asset ) = @_;
    my $filter_prop  = $self->{filter_property};
    my $filter_sense = $self->{filter_sense};
    my $filter_match = $self->{filter_match};

    return 1
        if !defined $filter_match;

    {
        no warnings 'uninitialized';
        if ($filter_sense) {
            return $asset->get($filter_prop) =~ $filter_match;
        }
        else {
            return $asset->get($filter_prop) !~ $filter_match;
        }
    }
}


1;

=head1 SYNOPSIS

    wgd cp [ --in-base-url | -b ] [ --recursive | -r] <asset> <newAssetUrl> <newAssetParentHint>

=head1 DESCRIPTION

Copies WebGUI asset(s), changing the url of the target.

=head1 OPTIONS

=over 8

=item C<-b> C<--in-base-url>

Applied to recursive operations.  Only includes assets whose url shares a common base-url with the parent's url.

=item C<-r> C<--recursive>

Recursively copy all descendants.

=cut

