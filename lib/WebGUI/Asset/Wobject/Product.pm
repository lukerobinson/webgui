package WebGUI::Asset::Wobject::Product;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2005 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use Tie::CPHash;
use WebGUI::HTMLForm;
use WebGUI::Icon;
use WebGUI::Privilege;
use WebGUI::Session;
use WebGUI::Storage;
use WebGUI::SQL;
use WebGUI::URL;
use WebGUI::Utility;
use WebGUI::Asset::Wobject;

# do a check to see if they've installed Image::Magick
my  $hasImageMagick = 1;
eval " use Image::Magick; "; $hasImageMagick=0 if $@;

our @ISA = qw(WebGUI::Asset::Wobject);

#-------------------------------------------------------------------
sub _addFileTab {
   my $self = shift;
   my $tabform = $_[0];
   my $column = $_[1];
   my $internationalId = $_[2];
   my ($value) = WebGUI::SQL->quickArray("select $column from Product where assetId=".quote($self->getId));
   if($value eq ""){
      $tabform->getTab("properties")->file(
	      -name=>$column,
		  -label=>WebGUI::International::get($internationalId,"Product"),
		);
      return;
   }
   
   my $file = WebGUI::Storage->get($value);
   $tabform->getTab("properties")->readOnly(
	      -value=>'<a href="'.$self->getUrl('func=deleteFileConfirm&file='.$column).'">'.WebGUI::International::get("deleteImage","Product").'</a>',
	      -label=>WebGUI::International::get($internationalId,"Product"),
	    );
}

#-------------------------------------------------------------------
sub _duplicateFile {
   my $self = shift;
   my $newAsset = $_[0];
   my $column = $_[1];
   if($self->get($column)){
      my $file = WebGUI::Storage->get($self->get($column));
	  my $newstore = $file->copy;
	  $newAsset->update({ $column=>$newstore->getId });
   }
}

#-------------------------------------------------------------------
sub _save {
   my $self = shift;
   return "" unless ($session{form}{$_[0]});
   my $file = WebGUI::Storage->create;
   $file->addFileFromFormPost($_[0]);
   $self->generateThumbnails($file);
   WebGUI::SQL->write("update Product set $_[0]=".quote($file->getId)." where assetId=".quote($self->getId));
}

#-------------------------------------------------------------------
sub definition {
	my $class = shift;
	my $definition = shift;
	push(@{$definition}, {
		tableName=>'Product',
		className=>'WebGUI::Asset::Wobject::Product',
		properties=>{
			templateId =>{
				fieldType=>"template",
				defaultValue=>'PBtmpl0000000000000056'
				},
			price=>{
			    fieldType=>"text",
				defaultValue=>undef
			}, 
			productNumber=>{
			    fieldType=>"text",
				defaultValue=>undef
			},
		  }
		});
        return $class->SUPER::definition($definition);
}

#-------------------------------------------------------------------
sub duplicate {
   my $self = shift;
   my $newAsset = $self->SUPER::duplicate(shift);
   
   my (%data, $file, $row, $sth, $newstore);
   tie %data, 'Tie::CPHash';
   
   $self->_duplicateFile($newAsset,"image1");
   $self->_duplicateFile($newAsset,"image2");
   $self->_duplicateFile($newAsset,"image3");
   $self->_duplicateFile($newAsset,"manual");
   $self->_duplicateFile($newAsset,"brochure");
   $self->_duplicateFile($newAsset,"warranty");
  
   $sth = WebGUI::SQL->read("select * from Product_feature where assetId=".quote($self->getId));
   while ($row = $sth->hashRef) {
      $row->{"Product_featureId"} = "new";
	  $row->{"assetId"} = $newAsset->getId; 
	  $newAsset->setCollateral("Product_feature","Product_featureId",$row);
   }
   $sth->finish;
   
   $sth = WebGUI::SQL->read("select * from Product_benefit where assetId=".quote($self->getId));
   while ($row = $sth->hashRef) {
      $row->{"Product_benefitId"} = "new";
	  $row->{"assetId"} = $newAsset->getId; 
      $newAsset->setCollateral("Product_benefit","Product_benefitId",$row);
   }
   $sth->finish;
   
   $sth = WebGUI::SQL->read("select * from Product_specification where assetId=".quote($self->getId));
   while ($row = $sth->hashRef) {
      $row->{"Product_specificationId"} = "new";
	  $row->{"assetId"} = $newAsset->getId; 
      $newAsset->setCollateral("Product_specification","Product_specificationId",$row);
   }
   $sth->finish;
   
   $sth = WebGUI::SQL->read("select * from Product_accessory where assetId=".quote($self->getId));
   while (%data = $sth->hash) {
      WebGUI::SQL->write("insert into Product_accessory (assetId,accessoryAssetId,sequenceNumber) values (".quote($newAsset->getId).", ".quote($data{accessoryAssetId}).", $data{sequenceNumber})");
   }
   $sth->finish;

   $sth = WebGUI::SQL->read("select * from Product_related where assetId=".quote($self->getId));
   while (%data = $sth->hash) {
      WebGUI::SQL->write("insert into Product_related (assetId,relatedAssetId,sequenceNumber) values (".quote($newAsset->getId).", ".quote($data{relatedAssetId}).", $data{sequenceNumber})");
   }
   $sth->finish;
}

#-------------------------------------------------------------------

=head2 generateThumbnails ( filestore, [ thumbnailSize ] ) 

Generates a thumbnail for this image.

=head3 thumbnailSize

A size, in pixels, of the maximum height or width of a thumbnail. If specified this will change the thumbnail size of the image. If unspecified the thumbnail size set in the properties of this asset will be used.

=cut

sub generateThumbnails {
	my $self = shift;
	my $filestore = $_[0];
	my $thumbnailSize = $_[1] || $session{setting}{thumbnailSize} || 50;
	my $files = $filestore->getFiles();
	my $thumbErr = 1;
	foreach my $file (@{$files}){
	   if (defined $filestore && isIn(lc($filestore->getFileExtension($file)),qw(jpg jpeg gif png tif tiff bmp)) && $hasImageMagick) {
		  my $filePath = $filestore->getPath;
		  my $image = Image::Magick->new;
		  my $error = $image->Read($filePath.$session{os}{slash}.$file);
		  if ($error) {
		     WebGUI::ErrorHandler::warn("Couldn't read image for thumbnail creation: ".$error);
			 $thumbErr = 0;
		  }
          my ($x, $y) = $image->Get('width','height');
          my $n = $thumbnailSize;
          if ($x > $n || $y > $n) {
             my $r = $x>$y ? $x / $n : $y / $n;
             $image->Scale(width=>($x/$r),height=>($y/$r));
          }
          if (isIn($filestore->getFileExtension($file), qw(tif tiff bmp))) {
             $error = $image->Write($filePath.$session{os}{slash}.'thumb-'.$file.'.png');
          } else {
             $error = $image->Write($filePath.$session{os}{slash}.'thumb-'.$file);
          }
		  if ($error) {
		     WebGUI::ErrorHandler::warn("Couldn't create thumbnail: ".$error);
			 $thumbErr = 0;
		  }
	   }
	}
	return $thumbErr; # couldn't generate thumbnail
}

#-------------------------------------------------------------------
sub getEditForm {
	my $self = shift;
	my ($file);
	my $tabform = $self->SUPER::getEditForm();
	$tabform->getTab("display")->template(
      		-value=>$self->getValue('templateId'),
      		-namespace=>"Product"
   		);
	$tabform->getTab("properties")->text(
		-name=>"price",
		-label=>WebGUI::International::get(10,"Product"),
		-value=>$self->getValue("price")
		);
    $tabform->getTab("properties")->text(
		-name=>"productNumber",
		-label=>WebGUI::International::get(11,"Product"),
		-value=>$self->getValue("productNumber")
		);
    $self->_addFileTab($tabform,"image1",7);
	$self->_addFileTab($tabform,"image2",8);
	$self->_addFileTab($tabform,"image3",9);
	$self->_addFileTab($tabform,"brochure",13);
	$self->_addFileTab($tabform,"manual",14);
	$self->_addFileTab($tabform,"warranty",15);
	return $tabform;
}

#-------------------------------------------------------------------
sub getFileIconUrl {
   my $self = shift;
   my $store = $_[0];
   return $store->getFileIconUrl($self->getFilename($store));
}

#-------------------------------------------------------------------
sub getFilename {
   my $self = shift;
   my $store = $_[0];
   my $files = $store->getFiles();
   foreach my $file (@{$files}){
      unless($file =~ m/^thumb-/){
	     return $file;
	  }
   }
   return "";
}

#-------------------------------------------------------------------
sub getFileUrl {
	my $self = shift;
	my $store = $_[0];
   	return $store->getUrl($self->getFilename($store));
}

#-------------------------------------------------------------------
sub getIndexerParams {
	my $self = shift;        
	my $now = shift;
	return {
		Product => {
                        sql => "select Product.assetId,
					Product.image1,
					Product.image2,
					Product.image3,
					Product.brochure,
					Product.manual,
					Product.warranty,
					Product.price,
					Product.productNumber,
					Product_benefit.benefit,
					Product_feature.feature,
					Product_specification.name,
					Product_specification.value,
					Product_specification.units,
					asset.ownerUserId as ownerId,
					asset.url,
					asset.groupIdView,
					asset.title,
					asset.menuTitle,
					asset.className,
					asset.synopsis
				from Product, asset
					left join Product_benefit on Product_benefit.assetId=Product.assetId
					left join Product_feature on Product_feature.assetId=Product.assetId
					left join Product_specification on Product_specification.assetId=Product.assetId
				where Product.assetId = asset.assetId 
                                        and asset.startDate < $now
                                        and asset.endDate > $now",
                        fieldsToIndex => ["image1", "image2", "image3", "brochure", "manual", "warranty", "price", 
                                          "productNumber", "benefit", "feature", "name", "value", "units"],
                        contentType => 'content',
                        url => 'WebGUI::URL::gateway($data{url})',
                        headerShortcut => 'select title from asset where assetId = \'$data{assetId}\'',
                        bodyShortcut => 'select synopsis from asset where assetId = \'$data{asssetId}\'',
                }
	};
}

#-------------------------------------------------------------------
sub getName {
        return WebGUI::International::get(1,"Product");
}

#-------------------------------------------------------------------
sub getThumbnailFilename {
   my $self = shift;
   my $filestore = $_[0];
   my $files = $filestore->getFiles();
   foreach my $file (@{$files}){
      if($file =~ m/^thumb-/){
	     return $file;
	  }
   }
   return "";
}

#-------------------------------------------------------------------
sub getThumbnailUrl {
	my $self = shift;
	my $store = $_[0];
    return $store->getUrl($self->getThumbnailFilename($store));
}

#-------------------------------------------------------------------
sub purge {
   my $self = shift;
   my @array = WebGUI::SQL->quickArray("select image1, image2, image3, brochure, manual, warranty from Product where assetId=".quote($self->getId));
   foreach my $id (@array){
      next if ($id eq "");
	  my $store = WebGUI::Storage->get($id);
	  $store->delete; 
   }
   WebGUI::SQL->write("delete from Product_accessory where assetId=".quote($self->getId)." or accessoryAssetId=".quote($self->getId));
   WebGUI::SQL->write("delete from Product_related where assetId=".quote($self->getId)." or relatedAssetId=".quote($self->getId));
   WebGUI::SQL->write("delete from Product_benefit where assetId=".quote($self->getId));
   WebGUI::SQL->write("delete from Product_feature where assetId=".quote($self->getId));
   WebGUI::SQL->write("delete from Product_specification where assetId=".quote($self->getId));
   $self->SUPER::purge();
}


#-------------------------------------------------------------------
sub www_addAccessory {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   my ($f, $accessory, @usedAccessories);
   $f = WebGUI::HTMLForm->new(-action=>$self->getUrl);
   $f->hidden("func","addAccessorySave");
   @usedAccessories = WebGUI::SQL->buildArray("select accessoryAssetId from Product_accessory where assetId=".quote($self->getId));
   push(@usedAccessories,$self->getId);
   $accessory = WebGUI::SQL->buildHashRef("select assetId, title from asset where className='WebGUI::Asset::Wobject::Product' and assetId not in (".quoteAndJoin(\@usedAccessories).")");
   $f->selectList("accessoryAccessId",$accessory,WebGUI::International::get(17,'Product'));
   $f->yesNo("proceed",WebGUI::International::get(18,'Product'));
   $f->submit;
   return $self->getAdminConsole->render($f->print, "product accessory add/edit");
}

#-------------------------------------------------------------------
sub www_addAccessorySave {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   return "" unless ($session{form}{accessoryAccessId});
   my ($seq) = WebGUI::SQL->quickArray("select max(sequenceNumber) from Product_accessory where assetId=".quote($self->getId()));
   WebGUI::SQL->write("insert into Product_accessory (assetId,accessoryAssetId,sequenceNumber) values (".quote($self->getId()).",".quote($session{form}{accessoryAccessId}).",".($seq+1).")");
   return "" unless($session{form}{proceed});
   return $self->www_addAccessory();
}

#-------------------------------------------------------------------
sub www_addRelated {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   my ($f, $related, @usedRelated);
   $f = WebGUI::HTMLForm->new(-action=>$self->getUrl);
   $f->hidden("func","addRelatedSave");
   @usedRelated = WebGUI::SQL->buildArray("select relatedAssetId from Product_related where assetId=".quote($self->getId));
   push(@usedRelated,$self->getId);
   $related = WebGUI::SQL->buildHashRef("select assetId,title from asset where className='WebGUI::Asset::Wobject::Product' and assetId not in (".quoteAndJoin(\@usedRelated).")");
   $f->selectList("relatedAssetId",$related,WebGUI::International::get(20,'Product'));
   $f->yesNo("proceed",WebGUI::International::get(21,'Product'));
   $f->submit;
   return $self->getAdminConsole->render($f->print,"product related add/edit");
}

#-------------------------------------------------------------------
sub www_addRelatedSave {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   return "" unless ($session{form}{relatedAssetId});
   my ($seq) = WebGUI::SQL->quickArray("select max(sequenceNumber) from Product_related where assetId=".quote($self->getId));
   WebGUI::SQL->write("insert into Product_related (assetId,relatedAssetId,sequenceNumber) values (".quote($self->getId).",".quote($session{form}{relatedAssetId}).",".($seq+1).")");
   return "" unless($session{form}{proceed});
   return $self->www_addRelated();
}

#-------------------------------------------------------------------
sub www_deleteAccessoryConfirm {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   WebGUI::SQL->write("delete from Product_accessory where assetId=".quote($self->getId())." and accessoryAssetId=".quote($session{form}{aid}));
   $self->reorderCollateral("Product_accessory","accessoryAssetId");
   return "";
}

#-------------------------------------------------------------------
sub www_deleteBenefitConfirm {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $self->deleteCollateral("Product_benefit","Product_benefitId",$session{form}{bid});
   $self->reorderCollateral("Product_benefit","Product_benefitId");
   return "";
}

#-------------------------------------------------------------------
sub www_deleteFeatureConfirm {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $self->deleteCollateral("Product_feature","Product_featureId",$session{form}{fid});
   $self->reorderCollateral("Product_feature","Product_featureId");
   return "";
}

#-------------------------------------------------------------------
sub www_deleteFileConfirm {
   my $self = shift;
   my $column = $session{form}{file};
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   my $store = $self->get($column);
   my $file = WebGUI::Storage->get($store);
   $file->delete;
   WebGUI::SQL->write("update Product set $column=NULL where assetId=".quote($self->getId()));
   return $self->www_edit;
}

#-------------------------------------------------------------------
sub www_deleteRelatedConfirm {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   WebGUI::SQL->write("delete from Product_related where assetId=".quote($self->getId)." and relatedAssetId=".quote($session{form}{rid}));
   $self->reorderCollateral("Product_related","relatedAssetId");
   return "";
}

#-------------------------------------------------------------------
sub www_deleteSpecificationConfirm {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $self->deleteCollateral("Product_specification","Product_specificationId",$session{form}{sid});
   $self->reorderCollateral("Product_specification","Product_specificationId");
   return "";
}

#-------------------------------------------------------------------
sub www_edit {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless $self->canEdit;
   $self->getAdminConsole->setHelp("product add/edit","Product");
   return $self->getAdminConsole->render($self->getEditForm->print,WebGUI::International::get("6","Product"));
}

#-------------------------------------------------------------------
sub www_editSave {
	my $self = shift;
	return WebGUI::Privilege::insufficient() unless ($self->canEdit);
	$self->SUPER::www_editSave();
	$self->_save("image1");
	$self->_save("image2");
	$self->_save("image3");
	$self->_save("brochure");
	$self->_save("manual");
	$self->_save("warranty");
	return "";
}

#-------------------------------------------------------------------
sub www_editBenefit {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   my ($data, $f, $benefits);
   $data = $self->getCollateral("Product_benefit","Product_benefitId",$session{form}{bid});
   $f = WebGUI::HTMLForm->new(-action=>$self->getUrl);
   $f->hidden("bid",$data->{Product_benefitId});
   $f->hidden("func","editBenefitSave");
   $benefits = WebGUI::SQL->buildHashRef("select benefit,benefit from Product_benefit order by benefit");
   $f->combo("benefit",$benefits,WebGUI::International::get(51,'Product'),[$data->{benefits}]);
   $f->yesNo("proceed",WebGUI::International::get(52,'Product'));
   $f->submit;
   return $self->getAdminConsole->render($f->print, "product benefit add/edit");
}

#-------------------------------------------------------------------
sub www_editBenefitSave {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $session{form}{benefit} = $session{form}{benefit_new} if ($session{form}{benefit_new} ne "");
   $self->setCollateral("Product_benefit", "Product_benefitId", {
		                                          Product_benefitId => $session{form}{bid},
		                                          benefit => $session{form}{benefit}
		                                        });
   
   return "" unless($session{form}{proceed});
   $session{form}{bid} = "new";
   return $self->www_editBenefit();
}

#-------------------------------------------------------------------
sub www_editFeature {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   my ($data, $f, $features);
   $data = $self->getCollateral("Product_feature","Product_featureId",$session{form}{fid});
   $f = WebGUI::HTMLForm->new(-action=>$self->getUrl);
   $f->hidden("fid",$data->{Product_featureId});
   $f->hidden("func","editFeatureSave");
   $features = WebGUI::SQL->buildHashRef("select feature,feature from Product_feature order by feature");
   $f->combo("feature",$features,WebGUI::International::get(23,'Product'),[$data->{feature}]);
   $f->yesNo("proceed",WebGUI::International::get(24,'Product'));
   $f->submit;
   return $self->getAdminConsole->render($f->print, "product feature add/edit");
}

#-------------------------------------------------------------------
sub www_editFeatureSave {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $session{form}{feature} = $session{form}{feature_new} if ($session{form}{feature_new} ne "");
   $self->setCollateral("Product_feature", "Product_featureId", {
                                              Product_featureId => $session{form}{fid},
                                              feature => $session{form}{feature}
                                             });
   return "" unless($session{form}{proceed});
   $session{form}{fid} = "new";
   return $self->www_editFeature();
}

#-------------------------------------------------------------------
sub www_editSpecification {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   my ($data, $f, $hashRef);
   $data = $self->getCollateral("Product_specification","Product_specificationId",$session{form}{sid});
   $f = WebGUI::HTMLForm->new(-action=>$self->getUrl);
   $f->hidden("sid",$data->{Product_specificationId});
   $f->hidden("func","editSpecificationSave");
   $hashRef = WebGUI::SQL->buildHashRef("select name,name from Product_specification order by name");
   $f->combo("name",$hashRef,WebGUI::International::get(26,'Product'),[$data->{name}]);
   $f->text("value",WebGUI::International::get(27,'Product'),$data->{value});
   $hashRef = WebGUI::SQL->buildHashRef("select units,units from Product_specification order by units");
   $f->combo("units",$hashRef,WebGUI::International::get(29,'Product'),[$data->{units}]);
   $f->yesNo("proceed",WebGUI::International::get(28,'Product'));
   $f->submit;
   return $self->getAdminConsole->render($f->print, "product specification add/edit");
}

#-------------------------------------------------------------------
sub www_editSpecificationSave {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $session{form}{name} = $session{form}{name_new} if ($session{form}{name_new} ne "");
   $session{form}{units} = $session{form}{units_new} if ($session{form}{units_new} ne "");
   $self->setCollateral("Product_specification", "Product_specificationId", {
                                    Product_specificationId => $session{form}{sid},
                                    name => $session{form}{name},
                                    value => $session{form}{value},
                                    units => $session{form}{units}
                                  });
   
   return "" unless($session{form}{proceed});
   $session{form}{sid} = "new";
   return $self->www_editSpecification();
}

#-------------------------------------------------------------------
sub www_moveAccessoryDown {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $self->moveCollateralDown("Product_accessory","accessoryAssetId",$session{form}{aid});
   return "";
}

#-------------------------------------------------------------------
sub www_moveAccessoryUp {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $self->moveCollateralUp("Product_accessory","accessoryAssetId",$session{form}{aid});
   return "";
}

#-------------------------------------------------------------------
sub www_moveBenefitDown {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $self->moveCollateralDown("Product_benefit","Product_benefitId",$session{form}{bid});
   return "";
}

#-------------------------------------------------------------------
sub www_moveBenefitUp {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $self->moveCollateralUp("Product_benefit","Product_benefitId",$session{form}{bid});
   return "";
}

#-------------------------------------------------------------------
sub www_moveFeatureDown {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $self->moveCollateralDown("Product_feature","Product_featureId",$session{form}{fid});
   return "";
}

#-------------------------------------------------------------------
sub www_moveFeatureUp {
	my $self = shift;
	return WebGUI::Privilege::insufficient() unless ($self->canEdit);
	$self->moveCollateralUp("Product_feature","Product_featureId",$session{form}{fid});
	return "";
}

#-------------------------------------------------------------------
sub www_moveRelatedDown {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $self->moveCollateralDown("Product_related","relatedAssetId",$session{form}{rid});
   return "";
}

#-------------------------------------------------------------------
sub www_moveRelatedUp {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $self->moveCollateralUp("Product_related","relatedAssetId",$session{form}{rid});
   return "";
}

#-------------------------------------------------------------------
sub www_moveSpecificationDown {
   my $self = shift;
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $self->moveCollateralDown("Product_specification","Product_specificationId",$session{form}{sid});
   return "";
}

#-------------------------------------------------------------------
sub www_moveSpecificationUp {
   my $self = shift;   
   return WebGUI::Privilege::insufficient() unless ($self->canEdit);
   $self->moveCollateralUp("Product_specification","Product_specificationId",$session{form}{sid});
   return "";
}

#-------------------------------------------------------------------
sub view {
   my $self = shift;
   $self->logView() if ($session{setting}{passiveProfilingEnabled});
   my (%data, $sth, $file, $segment, %var, @featureloop, @benefitloop, @specificationloop, @accessoryloop, @relatedloop);
   tie %data, 'Tie::CPHash';
   my ($image1, $image2, $image3, $brochure, $manual, $warranty) = WebGUI::SQL->quickArray("select image1, image2, image3, brochure, manual, warranty from Product where assetId=".quote($self->getId));
   #---brochure
   if ($brochure) {
      $file = WebGUI::Storage->get($brochure);
      $var{"brochure.icon"} = $self->getFileIconUrl($file);
	  $var{"brochure.label"} = WebGUI::International::get(13,"Product");
	  $var{"brochure.URL"} = $self->getFileUrl($file);
   }
	#---manual
   if ($manual) {
      $file = WebGUI::Storage->get($manual);
	  $var{"manual.icon"} = $self->getFileIconUrl($file);
	  $var{"manual.label"} = WebGUI::International::get(14,"Product");
      $var{"manual.URL"} = $self->getFileUrl($file);
   }
   #---warranty
   if ($warranty) {
      $file = WebGUI::Storage->get($warranty);
      $var{"warranty.icon"} = $self->getFileIconUrl($file);
	  $var{"warranty.label"} = WebGUI::International::get(15,"Product");
	  $var{"warranty.URL"} = $self->getFileUrl($file);
   }
   #---image1
   if ($image1) {
      $file = WebGUI::Storage->get($image1);
      $var{thumbnail1} = $self->getThumbnailUrl($file);
	  $var{image1} = $self->getFileUrl($file);
   }
   #---image2
   if ($image2) {
      $file = WebGUI::Storage->get($image2);
      $var{thumbnail2} = $self->getThumbnailUrl($file);
      $var{image2} = $self->getFileUrl($file);
   }
   #---image3
   if ($image3) {
      $file = WebGUI::Storage->get($image3);
      $var{thumbnail3} = $self->getThumbnailUrl($file);
      $var{image3} = $self->getFileUrl($file);
   }
   
   #---features 
   $var{"addFeature.url"} = $self->getUrl('func=editFeature&fid=new');
   $var{"addFeature.label"} = WebGUI::International::get(34,'Product');
   $sth = WebGUI::SQL->read("select feature,Product_featureId from Product_feature where assetId=".quote($self->getId)." order by sequenceNumber");
   while (%data = $sth->hash) {
      $segment = deleteIcon('func=deleteFeatureConfirm&fid='.$data{Product_featureId},$self->get("url"),WebGUI::International::get(3,'Product'))
                 .editIcon('func=editFeature&fid='.$data{Product_featureId},$self->get("url"))
                 .moveUpIcon('func=moveFeatureUp&&fid='.$data{Product_featureId},$self->get("url"))
                 .moveDownIcon('func=moveFeatureDown&&fid='.$data{Product_featureId},$self->get("url"));
	  push(@featureloop,{
			              "feature.feature"=>$data{feature},
			              "feature.controls"=>$segment
			             });
   }
   $sth->finish;
   $var{feature_loop} = \@featureloop;

   #---benefits 
   $var{"addBenefit.url"} = $self->getUrl('func=editBenefit&fid=new');
   $var{"addBenefit.label"} = WebGUI::International::get(55,'Product');
   $sth = WebGUI::SQL->read("select benefit,Product_benefitId from Product_benefit where assetId=".quote($self->getId)." order by sequenceNumber");
   while (%data = $sth->hash) {
      $segment = deleteIcon('func=deleteBenefitConfirm&bid='.$data{Product_benefitId},$self->get("url"),WebGUI::International::get(48,'Product'))
                 .editIcon('func=editBenefit&bid='.$data{Product_benefitId},$self->get("url"))
                 .moveUpIcon('func=moveBenefitUp&bid='.$data{Product_benefitId},$self->get("url"))
                 .moveDownIcon('func=moveBenefitDown&bid='.$data{Product_benefitId},$self->get("url"));
	  push(@benefitloop,{
			              "benefit.benefit"=>$data{benefit},
			              "benefit.controls"=>$segment
			             });
   }
   $sth->finish;
   $var{benefit_loop} = \@benefitloop;

   #---specifications 
   $var{"addSpecification.url"} = $self->getUrl('func=editSpecification&sid=new');
   $var{"addSpecification.label"} = WebGUI::International::get(35,'Product');
   $sth = WebGUI::SQL->read("select name,value,units,Product_specificationId from Product_specification where assetId=".quote($self->getId)." order by sequenceNumber");
   while (%data = $sth->hash) {
      $segment = deleteIcon('func=deleteSpecificationConfirm&sid='.$data{Product_specificationId},$self->get("url"),WebGUI::International::get(5,'Product'))
                 .editIcon('func=editSpecification&sid='.$data{Product_specificationId},$self->get("url"))
                 .moveUpIcon('func=moveSpecificationUp&sid='.$data{Product_specificationId},$self->get("url"))
                 .moveDownIcon('func=moveSpecificationDown&sid='.$data{Product_specificationId},$self->get("url"));
      push(@specificationloop,{
			                      "specification.controls"=>$segment,
			                      "specification.specification"=>$data{value},
			                      "specification.units"=>$data{units},
			                      "specification.label"=>$data{name}
		                       });
   }
   $sth->finish;
   $var{specification_loop} = \@specificationloop;

	#---accessories 
   $var{"addaccessory.url"} = $self->getUrl('func=addAccessory');
   $var{"addaccessory.label"} = WebGUI::International::get(36,'Product');
   $sth = WebGUI::SQL->read("select asset.title, asset.url, Product_accessory.accessoryAssetId 
                             from   Product_accessory,asset 
		                     where Product_accessory.assetId=".quote($self->getId)." 
		                     and Product_accessory.accessoryAssetId=asset.assetId 
		                     order by Product_accessory.sequenceNumber");
   while (%data = $sth->hash) {
      $segment = deleteIcon('func=deleteAccessoryConfirm&aid='.$data{accessoryAssetId},$self->get("url"),WebGUI::International::get(2,'Product'))
                 .moveUpIcon('func=moveAccessoryUp&aid='.$data{accessoryAssetId},$self->get("url"))
                 .moveDownIcon('func=moveAccessoryDown&aid='.$data{accessoryAssetId},$self->get("url"));
	  push(@accessoryloop,{
			               "accessory.URL"=>WebGUI::URL::gateway($data{url}),
			               "accessory.title"=>$data{title},
			               "accessory.controls"=>$segment
			               });
   }
   $sth->finish;
   $var{accessory_loop} = \@accessoryloop;

   #---related
   $var{"addrelatedproduct.url"} = $self->getUrl('func=addRelated');
   $var{"addrelatedproduct.label"} = WebGUI::International::get(37,'Product');
   $sth = WebGUI::SQL->read("select asset.title,asset.url,Product_related.relatedAssetId 
		                     from Product_related,asset 
		                     where Product_related.assetId=".quote($self->getId)." 
		                     and Product_related.relatedAssetId=asset.assetId 
		                     order by Product_related.sequenceNumber");
   while (%data = $sth->hash) {
      $segment = deleteIcon('func=deleteRelatedConfirm&rid='.$data{relatedAssetId},$self->get("url"),WebGUI::International::get(4,'Product'))
                 .moveUpIcon('func=moveRelatedUp&rid='.$data{relatedAssetId},$self->get("url"))
                 .moveDownIcon('func=moveRelatedDown&rid='.$data{relatedAssetId},$self->get("url"));
      push(@relatedloop,{
			              "relatedproduct.URL"=>WebGUI::URL::gateway($data{url}),
			              "relatedproduct.title"=>$data{title},
                          "relatedproduct.controls"=>$segment
			            });
   }
   $sth->finish;
   $var{relatedproduct_loop} = \@relatedloop;
   return $self->processTemplate(\%var, $self->get("templateId"));
}

1;

