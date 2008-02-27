package WebGUI::Asset::Sku::Donation;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2008 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use Tie::IxHash;
use base 'WebGUI::Asset::Sku';
use WebGUI::Asset::Template;
use WebGUI::Form;


=head1 NAME

Package WebGUI::Asset::Sku::Donation

=head1 DESCRIPTION

This asset makes donations possible.

=head1 SYNOPSIS

use WebGUI::Asset::Sku::Dnoation;

=head1 METHODS

These methods are available from this class:

=cut



#-------------------------------------------------------------------
sub definition {
	my $class = shift;
	my $session = shift;
	my $definition = shift;
	my %properties;
	tie %properties, 'Tie::IxHash';
	my $i18n = WebGUI::International->new($session, "Asset_Donation");
	%properties = (
		templateId => {
			tab             => "display",
			fieldType       => "template",
            namespace       => "Donation",
			defaultValue    => "vrKXEtluIhbmAS9xmPukDA",
			label           => $i18n->get("template"),
			hoverHelp       => $i18n->get("template help"),
			},
        thankYouMessage => {
            tab             => "properties",
			defaultValue    => $i18n->get("default thank you message"),
			fieldType       => "HTMLArea",
			label           => $i18n->get("thank you message"),
			hoverHelp       => $i18n->get("thank you message"),
            },
		defaultPrice => {
			tab             => "commerce",
			fieldType       => "float",
			defaultValue    => 100.00,
			label           => $i18n->get("default price"),
			hoverHelp       => $i18n->get("default price help"),
			},
	    );
	push(@{$definition}, {
		assetName           => $i18n->get('assetName'),
		icon                => 'Donation.gif',
		autoGenerateForms   => 1,
		tableName           => 'donation',
		className           => 'WebGUI::Asset::Sku::Donation',
		properties          => \%properties
	    });
	return $class->SUPER::definition($session, $definition);
}


#-------------------------------------------------------------------
sub getConfiguredTitle {
    my $self = shift;
    return $self->getTitle." (".$self->getOptions->{price}.")";
}


#-------------------------------------------------------------------
sub getPrice {
    my $self = shift;
    return $self->getOptions->{price} || $self->get("defaultPrice") || 100.00;
}

#-------------------------------------------------------------------
sub prepareView {
	my $self = shift;
	$self->SUPER::prepareView();
	my $templateId = $self->get("templateId");
	my $template = WebGUI::Asset::Template->new($self->session, $templateId);
	$template->prepare;
	$self->{_viewTemplate} = $template;
}

#-------------------------------------------------------------------
sub view {
    my ($self) = @_;
    my $session = $self->session;
	my $i18n = WebGUI::International->new($session, "Asset_Donation");
    my %var = (
        formHeader      => WebGUI::Form::formHeader($session, { action=>$self->getUrl })
            . WebGUI::Form::hidden( $session, { name=>"func", value=>"donate" }),
        formFooter      => WebGUI::Form::formFooter($session),
        donateButton    => WebGUI::Form::submit( $session, { value => $i18n->get("donate button") }),
        priceField      => WebGUI::Form::float($session, { name => "price", defaultValue => $self->getPrice }),
        hasAddedToCart  => $self->{_hasAddedToCart},
        );
    return $self->processTemplate(\%var,undef,$self->{_viewTemplate});
}

#-------------------------------------------------------------------
sub www_donate {
    my $self = shift;
    if ($self->canView) {
        $self->{_hasAddedToCart} = 1;
        $self->addToCart({price => ($self->session->form->get("price") || $self->getPrice) });
    }
    return $self->www_view;
}

1;
