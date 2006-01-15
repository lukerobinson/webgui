package WebGUI::Asset;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2006 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;

=head1 NAME

Package WebGUI::Asset

=head1 DESCRIPTION

This is a mixin package for WebGUI::Asset that contains all branch manipulation related functions.

=head1 SYNOPSIS

 use WebGUI::Asset;

=head1 METHODS

These methods are available from this class:

=cut



#-------------------------------------------------------------------

=head2 duplicateBranch ( [assetToDuplicate] )

Duplicates an asset and all its descendants. Calls addChild with assetToDuplicate as an argument. Returns a new Asset object.

=head3 assetToDuplicate

The asset to duplicate. Defaults to self.

=cut

sub duplicateBranch {
	my $self = shift;
	my $assetToDuplicate = shift || $self;
	my $newAsset = $self->duplicate($assetToDuplicate);
	my $contentPositions;
	$contentPositions = $assetToDuplicate->get("contentPositions");
	foreach my $child (@{$assetToDuplicate->getLineage(["children"],{returnObjects=>1})}) {
		my $newChild = $newAsset->duplicateBranch($child);
		if ($contentPositions) {
			my $newChildId = $newChild->getId;
			my $oldChildId = $child->getId;
			$contentPositions =~ s/${oldChildId}/${newChildId}/g;
		}
	}
	$newAsset->update({contentPositions=>$contentPositions}) if $contentPositions;
	return $newAsset;
}


#-------------------------------------------------------------------

=head2 purgeBranch ( )

Returns 1. Purges self and all descendants.

=cut

sub purgeBranch {
	my $self = shift;
	my $descendants = $self->getLineage(["self","descendants"],{returnObjects=>1, invertTree=>1, statesToInclude=>['published', 'clipboard', 'clipboard-limbo','trash','trash-limbo']});
	foreach my $descendant (@{$descendants}) {
		$descendant->purge;
	}
	return 1;
}


#-------------------------------------------------------------------

=head2 www_editBranch ( )

Creates a tabform to edit the Asset Tree. If canEdit returns False, returns insufficient Privilege page. 

=cut

sub www_editBranch {
	my $self = shift;
	my $ac = WebGUI::AdminConsole->new($self->session,"assets");
	my $i18n = WebGUI::International->new($self->session,"Asset");
	return $self->session->privilege->insufficient() unless ($self->canEdit);
	my $tabform = WebGUI::TabForm->new;
	$tabform->hidden({name=>"func",value=>"editBranchSave"});
	$tabform->addTab("properties",$i18n->get("properties"),9);
        $tabform->getTab("properties")->readOnly(
                -label=>$i18n->get(104),
                -uiLevel=>9,
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_url"}),
		-value=>WebGUI::Form::selectBox({
                	name=>"baseUrlBy",
			extras=>'onchange="toggleSpecificBaseUrl()"',
			id=>"baseUrlBy",
			options=>{
				parentUrl=>"Parent URL",
				specifiedBase=>"Specified Base",
				none=>"None"
				}
			}).'<span id="baseUrl"></span> / '.WebGUI::Form::selectBox({
				name=>"endOfUrl",
				options=>{
					menuTitle=>$i18n->get(411),
					title=>$i18n->get(99),
					currentUrl=>"Current URL"
					}
				})."<script type=\"text/javascript\">
			function toggleSpecificBaseUrl () {
				if (document.getElementById('baseUrlBy').options[document.getElementById('baseUrlBy').selectedIndex].value == 'specifiedBase') {
					document.getElementById('baseUrl').innerHTML='<input type=\"text\" name=\"baseUrl\" />';
				} else {
					document.getElementById('baseUrl').innerHTML='';
				}
			}
			toggleSpecificBaseUrl();
				</script>"
                );
	$tabform->addTab("display",$i18n->get(105),5);
	$tabform->getTab("display")->yesNo(
                -name=>"isHidden",
                -value=>$self->get("isHidden"),
                -label=>$i18n->get(886),
                -uiLevel=>6,
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_isHidden"})
                );
        $tabform->getTab("display")->yesNo(
                -name=>"newWindow",
                -value=>$self->get("newWindow"),
                -label=>$i18n->get(940),
                -uiLevel=>6,
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_newWindow"})
                );
	$tabform->getTab("display")->yesNo(
                -name=>"displayTitle",
                -label=>$i18n->get(174),
                -value=>$self->getValue("displayTitle"),
                -uiLevel=>5,
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_displayTitle"})
                );
         $tabform->getTab("display")->template(
		-name=>"styleTemplateId",
		-label=>$i18n->get(1073),
		-value=>$self->getValue("styleTemplateId"),
		-namespace=>'style',
		-afterEdit=>'op=editPage;npp='.$self->session->form->process("npp"),
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_styleTemplateId"})
		);
         $tabform->getTab("display")->template(
		-name=>"printableStyleTemplateId",
		-label=>$i18n->get(1079),
		-value=>$self->getValue("printableStyleTemplateId"),
		-namespace=>'style',
		-afterEdit=>'op=editPage;npp='.$self->session->form->process("npp"),
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_printableStyleTemplateId"})
		);
        $tabform->getTab("display")->interval(
                -name=>"cacheTimeout",
                -label=>$i18n->get(895),
                -value=>$self->getValue("cacheTimeout"),
                -uiLevel=>8,
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_cacheTimeout"})
                );
        $tabform->getTab("display")->interval(
                -name=>"cacheTimeoutVisitor",
                -label=>$i18n->get(896),
                -value=>$self->getValue("cacheTimeoutVisitor"),
                -uiLevel=>8,
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_cacheTimeoutVisitor"})
                );
	$tabform->addTab("security",$i18n->get(107),6);
        $tabform->getTab("security")->yesNo(
                -name=>"encryptPage",
                -value=>$self->get("encryptPage"),
                -label=>$i18n->get('encrypt page'),
                -uiLevel=>6,
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_encryptPage"})
                );
	$tabform->getTab("security")->dateTime(
                -name=>"startDate",
                -label=>$i18n->get(497),
                -value=>$self->get("startDate"),
                -uiLevel=>6,
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_startDate"})
                );
        $tabform->getTab("security")->dateTime(
                -name=>"endDate",
                -label=>$i18n->get(498),
                -value=>$self->get("endDate"),
                -uiLevel=>6,
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_endDate"})
                );
	my $subtext;
        if ($self->session->user->isInGroup(3)) {
                 $subtext = $self->session->icon->manage('op=listUsers');
        } else {
                 $subtext = "";
        }
        my $clause;
        if ($self->session->user->isInGroup(3)) {
                my $contentManagers = WebGUI::Group->new(4)->getUsers(1);
                push (@$contentManagers, $self->session->user->userId);
                $clause = "userId in (".$self->session->db->quoteAndJoin($contentManagers).")";
        } else {
                $clause = "userId=".$self->session->db->quote($self->get("ownerUserId"));
        }
        my $users = $self->session->db->buildHashRef("select userId,username from users where $clause order by username");
        $tabform->getTab("security")->selectBox(
               -name=>"ownerUserId",
               -options=>$users,
               -label=>$i18n->get(108),
               -value=>[$self->get("ownerUserId")],
               -subtext=>$subtext,
               -uiLevel=>6,
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_ownerUserId"})
               );
        $tabform->getTab("security")->group(
               -name=>"groupIdView",
               -label=>$i18n->get(872),
               -value=>[$self->get("groupIdView")],
               -uiLevel=>6,
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_groupIdView"})
               );
        $tabform->getTab("security")->group(
               -name=>"groupIdEdit",
               -label=>$i18n->get(871),
               -value=>[$self->get("groupIdEdit")],
               -excludeGroups=>[1,7],
               -uiLevel=>6,
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_groupIdEdit"})
		);
        $tabform->addTab("meta",$i18n->get("Metadata"),3);
        $tabform->getTab("meta")->textarea(
                -name=>"extraHeadTags",
                -label=>$i18n->get("extra head tags"),
                -hoverHelp=>$i18n->get('extra head tags description'),
                -value=>$self->get("extraHeadTags"),
                -uiLevel=>5,
		-subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_extraHeadTags"})
                );
        if ($self->session->setting->get("metaDataEnabled")) {
                my $meta = $self->getMetaDataFields();
                foreach my $field (keys %$meta) {
                        my $fieldType = $meta->{$field}{fieldType} || "text";
                        my $options;
                        # Add a "Select..." option on top of a select list to prevent from
                        # saving the value on top of the list when no choice is made.
                        if($fieldType eq "selectList") {
                                $options = {"", $i18n->get("Select")};
                        }
                        $tabform->getTab("meta")->dynamicField(
                                 name=>"metadata_".$meta->{$field}{fieldId},
                                 label=>$meta->{$field}{fieldName},
                                 uiLevel=>5,
                                 value=>$meta->{$field}{value},
                                 extras=>qq/title="$meta->{$field}{description}"/,
                                 possibleValues=>$meta->{$field}{possibleValues},
                                 options=>$options,
				 subtext=>'<br />'.$i18n->get("change").' '.WebGUI::Form::yesNo($self->session,{name=>"change_metadata_".$meta->{$field}{fieldId}}),
				fieldType=>$fieldType
                                );
                }
        }	
	return $ac->render($tabform->print, "Edit Branch");
}

#-------------------------------------------------------------------

=head2 www_editBranchSave ( )

Verifies proper inputs in the Asset Tree and saves them. Returns ManageAssets method. If canEdit returns False, returns an insufficient privilege page.

=cut

sub www_editBranchSave {
	my $self = shift;
	return $self->session->privilege->insufficient() unless ($self->canEdit);
	my %data;
	$data{isHidden} = $self->session->form->yesNo("isHidden") if ($self->session->form->yesNo("change_isHidden"));
	$data{newWindow} = $self->session->form->yesNo("newWindow") if ($self->session->form->yesNo("change_newWindow"));
	$data{displayTitle} = $self->session->form->yesNo("displayTitle") if ($self->session->form->yesNo("change_displayTitle"));
	$data{styleTemplateId} = $self->session->form->template("styleTemplateId") if ($self->session->form->yesNo("change_styleTemplateId"));
	$data{printableStyleTemplateId} = $self->session->form->template("printableStyleTemplateId") if ($self->session->form->yesNo("change_printableStyleTemplateId"));
	$data{cacheTimeout} = $self->session->form->interval("cacheTimeout") if ($self->session->form->yesNo("change_cacheTimeout"));
	$data{cacheTimeoutVisitor} = $self->session->form->interval("cacheTimeoutVisitor") if ($self->session->form->yesNo("change_cacheTimeoutVisitor"));
	$data{encryptPage} = $self->session->form->yesNo("encryptPage") if ($self->session->form->yesNo("change_encryptPage"));
	$data{startDate} = $self->session->form->dateTime("startDate") if ($self->session->form->yesNo("change_startDate"));
	$data{endDate} = $self->session->form->dateTime("endDate") if ($self->session->form->yesNo("change_endDate"));
	$data{ownerUserId} = $self->session->form->selectBox("ownerUserId") if ($self->session->form->yesNo("change_ownerUserId"));
	$data{groupIdView} = $self->session->form->group("groupIdView") if ($self->session->form->yesNo("change_groupIdView"));
	$data{groupIdEdit} = $self->session->form->group("groupIdEdit") if ($self->session->form->yesNo("change_groupIdEdit"));
	$data{extraHeadTags} = $self->session->form->group("extraHeadTags") if ($self->session->form->yesNo("change_extraHeadTags"));
	my ($urlBaseBy, $urlBase, $endOfUrl);
	my $changeUrl = $self->session->form->yesNo("change_url");
	if ($changeUrl) {
		$urlBaseBy = $self->session->form->selectBox("baseUrlBy");
		$urlBase = $self->session->form->text("baseUrl");
		$endOfUrl = $self->session->form->selectBox("endOfUrl");
	}
	my $descendants = $self->getLineage(["self","descendants"],{returnObjects=>1});	
	foreach my $descendant (@{$descendants}) {
		my $url;
		if ($changeUrl) {
			if ($urlBaseBy eq "parentUrl") {
				delete $descendant->{_parent};
				$data{url} = $descendant->getParent->get("url")."/";
			} elsif ($urlBaseBy eq "specifiedBase") {
				$data{url} = $urlBase."/";
			} else {
				$data{url} = "";
			}
			if ($endOfUrl eq "menuTitle") {
				$data{url} .= $descendant->get("menuTitle");
			} elsif ($endOfUrl eq "title") {
				$data{url} .= $descendant->get("title");
			} else {
				$data{url} .= $descendant->get("url");
			}
		}
		my $newRevision = $descendant->addRevision(\%data);
		foreach my $form ($self->session->request->param) {
                	if ($form =~ /^metadata_(.*)$/) {
				my $fieldName = $1;
				if ($self->session->form->yesNo("change_metadata_".$fieldName)) {
                        		$newRevision->updateMetaData($fieldName,$self->session->form->process($form));
				}
                	}
        	}
	}
	delete $self->{_parent};
	$self->session->asset = $self->getParent;
	return $self->getParent->www_manageAssets;
}



1;

