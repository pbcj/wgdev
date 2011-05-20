package WGDev::Command::Mv;
# ABSTRACT: Move WebGUI asset(s), either URL or parent or both.
use strict;
use warnings;
use 5.008008;

use WGDev::Command::Base;
BEGIN { our @ISA = qw(WGDev::Command::Base) }

sub config_options {
    return qw(
        notimpl-by-url|u
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
    #my $stayInBaseUrl        = $self->option('in-base-url');
    #my $byUrlOnly            = $self->option('by-url');

    my $error;
    
    my $asset;
    if ( !eval { $asset = $wgd->asset->find($fromAssetHint) } ) {
        warn "wgd mv: $fromAssetHint: No such asset\n";
        return;
    }
    
    die "Specify target or '.'" if !$toUrl;
    
    die "That would probably not do what you want.  (it would flatten the asset tree.  not implemented)" if $toUrl eq '.' && !defined $inParentHint;
    
    my $parent;
    eval {
        $parent = defined $inParentHint ? $wgd->asset->find( $inParentHint ) : $asset->getParent;
    };
    $error++ if $@;
  
    die "Specified parent was not found: $inParentHint" if !defined $parent;
    
    my $versionTag = WebGUI::VersionTag->create(
        $wgd->session,
        { groupToUse => 3, name => "wgd mv $fromAssetHint $toUrl" . defined $inParentHint ? $inParentHint : '' }
    );
    
    $versionTag->setWorking;
    
    # Move under new parent
    if( defined $inParentHint && $parent != $asset->getParent ) {
        $asset->setParent( $parent ) if defined $inParentHint;
    }
    
    # Change URL
    my $fromUrl = $asset->get( 'url' );
    $asset->update( { url => $toUrl } ) if( $toUrl ne '.' );
    
    # Recurse
    $self->moveChildren( $asset, $fromUrl, $toUrl ) if $asset->hasChildren;
    
    $versionTag->commit;
    return 1;    
    #return (! $error);
}

sub moveChildren {
    my ( $self, $asset, $fromUrl, $toUrl ) = @_;
    print 'moving /' , $asset->get( 'url' ) , "\n";
    my $children = $asset->getLineage( [ qw( children ) ], { returnObjects => 1 } );
    for my $child ( @$children ) {
        next if !( $child->get( 'url' ) =~ m/$fromUrl/ );
        next if $toUrl eq '.';
        
        my $newUrl = $child->get( 'url' );
        $newUrl =~ s/^$fromUrl/$toUrl/;
        $child->update( { url => $newUrl } );
        
        $self->moveChildren( $child, $fromUrl, $toUrl ) if $child->hasChildren;
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

    wgd mv <asset> <newAssetUrl> [ newAssetParentHint ]

=head1 DESCRIPTION

Moves WebGUI asset(s), either to a new parent, or changing the url of the target, or both.

If you don't wish to change the url, simply provide '.' (no quotes) as the newAssetUrl)

If you don't wish to move the node to a new parent, omit the newAssetParentHint argument.

=head1 OPTIONS

=over 8


=cut

