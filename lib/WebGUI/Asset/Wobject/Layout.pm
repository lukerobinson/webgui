package WebGUI::Asset::Wobject::Layout;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2005 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use WebGUI::Asset::Wobject;
use WebGUI::Icon;
use WebGUI::Session;
use WebGUI::Utility;

our @ISA = qw(WebGUI::Asset::Wobject);

=head1 NAME

Package WebGUI::Asset::Wobject::Layout

=head1 DESCRIPTION

Provides a mechanism to layout multiple assets on a single page.

=head1 SYNOPSIS

use WebGUI::Asset::Wobject::Layout;


=head1 METHODS

These methods are available from this class:

=cut



#-------------------------------------------------------------------

=head2 definition ( definition )

Defines the properties of this asset.

=head3 definition

A hash reference passed in from a subclass definition.

=cut

sub definition {
        my $class = shift;
        my $definition = shift;
        push(@{$definition}, {
                tableName=>'Layout',
                className=>'WebGUI::Asset::Wobject::Layout',
                properties=>{
			templateId =>{
				fieldType=>"template",
				defaultValue=>'PBtmpl0000000000000054'
				},
			contentPositions => {
				noFormPost=>1,
				defaultValue=>undef,
				fieldType=>"hidden"
				}
                        }
                });
        return $class->SUPER::definition($definition);
}



#-------------------------------------------------------------------

=head2 getEditForm ()

Returns the TabForm object that will be used in generating the edit page for this asset.

=cut

sub getEditForm {
	my $self = shift;
	my $tabform = $self->SUPER::getEditForm();
   	$tabform->getTab("display")->template(
      		-value=>$self->getValue('templateId'),
      		-namespace=>"Layout"
   		);
	if ($self->get("assetId") eq "new") {
               	$tabform->getTab("properties")->whatNext(
                       	-options=>{
                               	view=>WebGUI::International::get(823, 'Layout'),
                      	 	""=>WebGUI::International::get(847, 'Layout')
                              	},
			-value=>"view"
			);
	}
	return $tabform;
}


#-------------------------------------------------------------------
sub getIcon {
	my $self = shift;
	my $small = shift;
	return $session{config}{extrasURL}.'/assets/small/layout.gif' if ($small);
	return $session{config}{extrasURL}.'/assets/layout.gif';
}

#-------------------------------------------------------------------

=head2 getName ()

Returns the displayable name of this asset.

=cut

sub getName {
	return "Layout";
} 


#-------------------------------------------------------------------

=head2 getUiLevel ()

Returns the UI level of this asset.

=cut

sub getUiLevel {
	return 5;
}


#-------------------------------------------------------------------
sub view {
	my $self = shift;
	my $children = $self->getLineage( ["children"], { returnObjects=>1, excludeClasses=>["WebGUI::Asset::Wobject::Layout"] });
	my %vars;
	# I'm sure there's a more efficient way to do this. We'll figure it out someday.
	my @positions = split(/\./,$self->get("contentPositions"));
	my $i = 1;
	my @found;
	foreach my $position (@positions) {
		my @assets = split(",",$position);
		foreach my $asset (@assets) {
			foreach my $child (@{$children}) {
				if ($asset eq $child->getId) {
					push(@{$vars{"position".$i."_loop"}},{
						id=>$child->getId,
						content=>$child->view
						}) if $child->canView;	
					push(@found, $child->getId);
				}
			}
		}
		$i++;
	}
	# deal with unplaced children
	foreach my $child (@{$children}) {
		unless (isIn($child->getId, @found)) {
			push(@{$vars{"position1_loop"}},{
				id=>$child->getId,
				content=>$child->view
				}) if $child->canView;
		}
	}
	$vars{showAdmin} = ($session{var}{adminOn} && $self->canEdit);
	if ($vars{showAdmin}) {
		# under normal circumstances we don't put HTML stuff in our code, but this will make it much easier
		# for end users to work with our templates
		WebGUI::Style::setScript($session{config}{extrasURL}."/draggable.js",{ type=>"text/javascript", language=>"javascript"	});
		WebGUI::Style::setLink($session{config}{extrasURL}."/draggable.css",{ type=>"text/css", rel=>"stylesheet", media=>"all" });
		$vars{"dragger.icon"} = WebGUI::Icon::dragIcon();
		$vars{"dragger.init"} = '
			<iframe id="dragSubmitter" style="display: none;"></iframe>
			<script>
				dragable_init("'.$self->getUrl("func=setContentPositions&map=").'");
			</script>
			<style>
			.dragging, .empty {
				  background-image: url("'.$session{config}{extrasURL}.'/opaque.gif");
			}
			</style>
			';
	}

	return $self->processTemplate(\%vars,$self->get("templateId"));
}


sub www_edit {
        my $self = shift;
	return WebGUI::Privilege::insufficient() unless $self->canEdit;
        $self->getAdminConsole->setHelp("layout add/edit", "Layout");
        return $self->getAdminConsole->render($self->getEditForm->print,"Edit Layout");
}

sub www_setContentPositions {
	my $self = shift;
	return WebGUI::Privilege::insufficient() unless ($self->canEdit);
	$self->update({
		contentPositions=>$session{form}{map}
		});
	return "Map set: ".$session{form}{map};
}


1;

