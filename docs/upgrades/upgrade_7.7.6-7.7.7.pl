#!/usr/bin/env perl

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2009 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

our ($webguiRoot);

BEGIN {
    $webguiRoot = "../..";
    unshift (@INC, $webguiRoot."/lib");
}

use strict;
use Getopt::Long;
use WebGUI::Session;
use WebGUI::Storage;
use WebGUI::Asset;


my $toVersion = '7.7.7';
my $quiet; # this line required

my $session = start(); # this line required

addOgoneToConfig( $session );
addUseEmailAsUsernameToSettings( $session );
alterVATNumberTable( $session );
addRedirectAfterLoginUrlToSettings( $session );

finish($session); # this line required


#----------------------------------------------------------------------------
sub addOgoneToConfig {
    my $session = shift;
    print "\tAdding Ogone payment plugin..." unless $quiet;

    $session->config->addToArray('paymentDrivers', 'WebGUI::Shop::PayDriver::Ogone');
    
    print "Done\n" unless $quiet;
}

#----------------------------------------------------------------------------
sub addUseEmailAsUsernameToSettings {
    my $session = shift;
    print "\tAdding webguiUseEmailAsUsername to settings \n" unless $quiet;

    $session->db->write("insert into settings (name, value) values ('webguiUseEmailAsUsername',0)");

    print "Done.\n" unless $quiet;
}

#----------------------------------------------------------------------------
sub addRedirectAfterLoginUrlToSettings {
    my $session = shift;
    print "\tAdding redirectAfterLoginUrl to settings \n" unless $quiet;

    $session->db->write("insert into settings (name, value) values ('redirectAfterLoginUrl',NULL)");

    print "Done.\n" unless $quiet;
}

#----------------------------------------------------------------------------
sub alterVATNumberTable {
    my $session = shift;
    print "\tAdapting VAT Number table..." unless $quiet;

    $session->db->write('alter table tax_eu_vatNumbers change column approved viesValidated tinyint(1)');
    $session->db->write('alter table tax_eu_vatNumbers add column approved tinyint(1)');

    print "Done\n" unless $quiet;
}

# -------------- DO NOT EDIT BELOW THIS LINE --------------------------------

#----------------------------------------------------------------------------
# Add a package to the import node
sub addPackage {
    my $session     = shift;
    my $file        = shift;

    # Make a storage location for the package
    my $storage     = WebGUI::Storage->createTemp( $session );
    $storage->addFileFromFilesystem( $file );

    # Import the package into the import node
    my $package = WebGUI::Asset->getImportNode($session)->importPackage( $storage );

    # Turn off the package flag, and set the default flag for templates added
    my $assetIds = $package->getLineage( ['self','descendants'] );
    for my $assetId ( @{ $assetIds } ) {
        my $asset   = WebGUI::Asset->newByDynamicClass( $session, $assetId );
        if ( !$asset ) {
            print "Couldn't instantiate asset with ID '$assetId'. Please check package '$file' for corruption.\n";
            next;
        }
        my $properties = { isPackage => 0 };
        if ($asset->isa('WebGUI::Asset::Template')) {
            $properties->{isDefault} = 1;
        }
        $asset->update( $properties );
    }

    return;
}

#-------------------------------------------------
sub start {
    my $configFile;
    $|=1; #disable output buffering
    GetOptions(
        'configFile=s'=>\$configFile,
        'quiet'=>\$quiet
    );
    my $session = WebGUI::Session->open($webguiRoot,$configFile);
    $session->user({userId=>3});
    my $versionTag = WebGUI::VersionTag->getWorking($session);
    $versionTag->set({name=>"Upgrade to ".$toVersion});
    return $session;
}

#-------------------------------------------------
sub finish {
    my $session = shift;
    updateTemplates($session);
    my $versionTag = WebGUI::VersionTag->getWorking($session);
    $versionTag->commit;
    $session->db->write("insert into webguiVersion values (".$session->db->quote($toVersion).",'upgrade',".$session->datetime->time().")");
    $session->close();
}

#-------------------------------------------------
sub updateTemplates {
    my $session = shift;
    return undef unless (-d "packages-".$toVersion);
    print "\tUpdating packages.\n" unless ($quiet);
    opendir(DIR,"packages-".$toVersion);
    my @files = readdir(DIR);
    closedir(DIR);
    my $newFolder = undef;
    foreach my $file (@files) {
        next unless ($file =~ /\.wgpkg$/);
        # Fix the filename to include a path
        $file       = "packages-" . $toVersion . "/" . $file;
        addPackage( $session, $file );
    }
}

#vim:ft=perl
