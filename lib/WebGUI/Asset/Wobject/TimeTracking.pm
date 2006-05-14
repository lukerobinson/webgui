package WebGUI::Asset::Wobject::TimeTracking;

$VERSION = "1.0.0";

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2006 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use DateTime;
use Tie::IxHash;
use WebGUI::International;
use WebGUI::Utility;
use POSIX qw(ceil floor);
use base 'WebGUI::Asset::Wobject';


#-------------------------------------------------------------------
sub definition {
	my $class = shift;
	my $session = shift;
	my $definition = shift;
	my $i18n = WebGUI::International->new($session,'Asset_TimeTracking');
	my %properties;
	tie %properties, 'Tie::IxHash';
	%properties = (
		userViewTemplateId =>{
			fieldType=>"template",  
			defaultValue=>'TimeTrackingTMPL000001',
			tab=>"display",
			namespace=>"TimeTracking_user", 
			hoverHelp=>$i18n->get('userViewTemplate hoverhelp'),
		    label=>$i18n->get('userViewTemplate label')
		},
		managerViewTemplateId => {
			fieldType=>"template",  
			defaultValue=>'TimeTrackingTMPL000002',
			tab=>"display",
			namespace=>"TimeTracking_manager", 
			hoverHelp=>$i18n->get('managerViewTemplate hoverhelp'),
		    label=>$i18n->get('managerViewTemplate label')
		},
		timeRowTemplateId=>  {
			fieldType=>"template",  
			defaultValue=>'TimeTrackingTMPL000003',
			tab=>"display",
			namespace=>"TimeTracking_row", 
			hoverHelp=>$i18n->get('timeRowTemplateId hoverhelp'),
		    label=>$i18n->get('timeRowTemplateId label')
		},
		groupToManage => {
			fieldType=>"group",
			defaultValue=>3,
			tab=>"security",
			hoverHelp=>$i18n->get('groupToManage hoverhelp'),
			label=>$i18n->get('groupToManage label')
		}
	);
	push(@{$definition}, {
		assetName=>$i18n->get('assetName'),
		icon=>'timetrack.gif',
		autoGenerateForms=>1,
		tableName=>'TT_wobject',
		className=>'WebGUI::Asset::Wobject::TimeTracking',
		properties=>\%properties
	 });
     return $class->SUPER::definition($session, $definition);
}


#-------------------------------------------------------------------
sub duplicate {
	my $self = shift;
	my $newAsset = $self->SUPER::duplicate(shift);
	return $newAsset;
}

#-------------------------------------------------------------------
sub prepareView {
	my $self = shift;
	$self->SUPER::prepareView();
	my $template;
	#if($user->isInGroup($self->get("groupToManage")) {
	#  $template = WebGUI::Asset::Template->new($self->session, $self->get("managerViewTemplateId"));
	#} else {
	   $template = WebGUI::Asset::Template->new($self->session, $self->get("userViewTemplateId"));
	#}
	$template->prepare;
	$self->{_viewTemplate} = $template;
}

#-------------------------------------------------------------------
sub processErrors {
   my $self = shift;
   my $errors = "";
   if($_[0]) {
      $errors = "<ul>";
	  foreach (@{$_[0]}) {
	     $errors .= "<li>$_</li>";
	  }
	  $errors .= "</ul>";
   }
   return $errors;
}


#-------------------------------------------------------------------
sub purge {
	my $self = shift;
	#purge your wobject-specific data here.  This does not include fields 
	# you create for your NewWobject asset/wobject table.
	return $self->SUPER::purge;
}

#-------------------------------------------------------------------
sub setSessionVars {
   my $self = shift;
   my $session = $self->session;
   my $i18n = WebGUI::International->new($session,'Asset_TimeTracking');
   
   return ($session,$session->privilege,$session->form,$session->db,$session->datetime,$i18n,$session->user);
}

#-------------------------------------------------------------------
sub getSessionVars {
   my $self = shift;
   my $vars = $_[0];
   return () unless $vars;
   
   my @list = ();
   my $session = $self->session;
   push(@list, $session);
   
   foreach my $var (@{$vars}) {
      if($var eq "i18n") {
	     push(@list,WebGUI::International->new($session,'Asset_ProjectManager'));
	  }
      push(@list, $session->$var);
   }   
   return @list;
}


#-------------------------------------------------------------------
sub view {
	my $self = shift;
	my $var = $self->get;
	
	my ($session,$privilege,$form,$db,$dt,$i18n,$user) = $self->setSessionVars;
	my $config = $session->config;
	my $eh = $session->errorHandler;
	
	$var->{'extras'} = $config->get("extrasURL")."/wobject/TimeTracking"; 
	
	if($user->isInGroup($self->get("groupToManage"))) {
	   #Return manager screen
	   #$self->_buildManagerView($var);
	}
	
	$self->_buildUserView($var);
	
	return $self->processTemplate($var, undef, $self->{_viewTemplate});
}

#-------------------------------------------------------------------
sub _buildUserView {
	my $self = shift;
	my $var = $_[0];
	
	my @vars = ("privilege","form","db","datetime","i18n","user","eh");
	my ($session,$privilege,$form,$db,$dt,$i18n,$user,$eh) = $self->getSessionVars(\@vars);
	
	$var->{'form.header'} = WebGUI::Form::formHeader($session,{
				action=>$self->getUrl,
				extras=>q|name="editTimeForm"|
				});
	$var->{'form.header'} .= WebGUI::Form::hidden($session, {
				-name=>"func",
				-value=>"editTimeEntrySave"
				});
				
	$var->{'form.footer'} = WebGUI::Form::formFooter($session);
	
	$var->{'form.timetracker'} = $self->_buildTimeTable($var);
	
	return;
}

#-------------------------------------------------------------------
sub _buildTimeTable {
   	my $self = shift;
	my $viewVar = $_[0];
	my $var = {};
	
	$var->{'extras'} = $viewVar->{'extras'}; 
	my @vars = ("datetime","i18n","eh","form","db","user");
	my ($session,$dt,$i18n,$eh,$form,$db,$user) = $self->getSessionVars(\@vars);
	
	my $week = $form->get("week") || $dt->time;
	my $daysInWeek = $self->getDaysInWeek($week);
	my $endOfWeek = $dt->epochToSet($daysInWeek->{"6"});
	
	$var->{'time.report.header'} = sprintf($i18n->get("time report header"),$endOfWeek);
	$var->{'time.report.hours.label'} = $i18n->get("total hours label");
	$var->{'time.report.date.label'} = $i18n->get("time report date label");
	$var->{'time.report.project.label'} = $i18n->get("time report project label");
	$var->{'time.report.task.label'} = $i18n->get("time report task label");
	$var->{'time.report.hours.label'} = $i18n->get("time report hours label");
	$var->{'time.report.comments.label'} = $i18n->get("time report comments label");

	my $weekStart = $daysInWeek->{"0"};
	my ($junk,$weekEnd) = $dt->dayStartEnd($daysInWeek->{"6"});
	
	my $entries = $db->buildArrayRefOfHashRefs("select * from TT_timeEntry where resourceId=".$db->quote($user->userId)." and date >= ".$db->quote($weekStart)." and date <=".$db->quote($weekEnd));
	my $rowCount = 1;
	my @timeEntries = ();
	foreach my $entry (@{$entries}) {
	   push (@timeEntries,$self->_buildRow($entry,$rowCount++));
	}
	
	#Seed time tracker with 10 empty rows
	for( my $i = $rowCount; $i < ($rowCount + 10); $i++) {
	   push(@timeEntries,$self->_buildRow(undef,$i));
	}
	
	$var->{'time.entry.loop'} = \@timeEntries;
	$viewVar->{'time.report.rows.total'} = scalar(@timeEntries);
	
    return $self->processTemplate($var,$self->getValue("timeRowTemplateId"));
}

#-------------------------------------------------------------------
sub _buildRow {
	my $self = shift;
	my ($session,$dt,$i18n,$eh,$form,$db,$user) = $self->getSessionVars(("datetime","i18n","eh","form","db","user"));
	
	my $var = {};
	my $entry = $_[0] || {};
	my $rowCount = $_[1];
	
	my $entryId = $entry->{entryId};
	$var->{'row.id'} = "row_$rowCount";
	$var->{'row.id'} .= "_$entryId" if($entryId);
	my $projectId = $entry->{projectId};
	my $taskId = $entry->{taskId};
	
	my $pmAssetId = $self->getValue("pmAssetId");
	
	#Entry Date
	$var->{'form.date'} = WebGUI::Form::date($session,{
				-name=>"taskDate_$rowCount",
				-value=>$entry->{taskDate}
				});
	
	#Entry Project
	tie my %projectList, "Tie::IxHash";
	if($pmAssetId) {
	   #Build project list and task lists from project management app
	} else {
	   %projectList = $db->buildHashRef("select a.projectId, a.projectName from TT_projectList a, TT_projectResourceList b where a.projectId=b.projectId and b.resourceId=".$db->quote($user->userId));
	}
	$var->{'form.project'} = WebGUI::Form::selectBox($session,{
	            -name=>"projectId_$rowCount",
				-options=>\%projectList,
				-value=>$projectId
	            });
	
	#Entry Task
	tie my %taskList, "Tie::IxHash";
	if($entryId) {
	   if($pmAssetId) {
	      #Build task list for project from project managmenet app
	   } else {
	      %taskList = $db->buildHashRef("select taskName, taskId from TT_projectTasks where projectId=".$db->quote($projectId));
	   }
	} else {
	   %taskList = ("","Choose One");
	}
	$var->{'form.task'} = WebGUI::Form::selectBox($session,{
	            -name=>"taskId_$rowCount",
				-options=>\%taskList,
				-value=>$taskId
	            });
	
	#Entry Hours
	$var->{'form.hours'} = WebGUI::Form::float($session, {
				-name=>"hours_$rowCount",
				-value=>$entry->{hours}
				});
	
	#Entry Comments
	$var->{'form.comments'} = WebGUI::Form::text($session, {
	             -name=>"comments_$rowCount",
				 -value=>$entry->{comments},
				 -size=>53
				});
	
	$var->{'delete.url'} = "";	
	return $var;

}

#-------------------------------------------------------------------
sub getDaysInWeek {
	my $self = shift;
	my $week = $_[0];
	return [] unless $week;
	
	my ($session,$dt,$i18n,$eh) = $self->getSessionVars(("datetime","i18n","eh"));
	
    #Week View Below
	my ($dayStart,$dayEnd) = $dt->dayStartEnd($week);
    my $dayOfWeek = $dt->getDayOfWeek($dayStart);
    my $sundayAdjust = (7 - $dayOfWeek);
    
	my $weekStart = $dt->addToDateTime($dayStart,0,0,$sundayAdjust,1);
	
	tie my %hash, "Tie::IxHash";
	$hash{"0"} = $weekStart;
	for (my $i = 1; $i < 7; $i++) {
	   $hash{$i} = $dt->addToDate($weekStart,0,0,$i);
	}
	
	return \%hash;
}

1;
