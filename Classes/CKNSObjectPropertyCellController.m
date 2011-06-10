//
//  CKNSObjectPropertyCellController.m
//  CloudKit
//
//  Created by Sebastien Morel on 11-06-09.
//  Copyright 2011 WhereCloud Inc. All rights reserved.
//

#import "CKNSObjectPropertyCellController.h"

#import "CKPropertyGridEditorController.h"

#import "CKNSNumberPropertyCellController.h"
#import "CKNSStringPropertyCellController.h"
#import "CKNSObject+Bindings.h"
#import "CKLocalization.h"
#import "CKOptionCellController.h"
#import "CKObjectPropertyArrayCollection.h"
#import "CKNSValueTransformer+Additions.h"
#import "CKNSObjectPropertyCellController.h"

#import "CKClassExplorer.h"

@interface CKUIBarButtonItemWithInfo : UIBarButtonItem{
	id userInfo;
}
@property(nonatomic,retain)id userInfo;
@end

@implementation CKUIBarButtonItemWithInfo
@synthesize userInfo;
- (void)dealloc{
	[userInfo release];
	[super dealloc];
}
@end

@interface CKUIButtonWithInfo : UIButton{
	id userInfo;
}
@property(nonatomic,retain)id userInfo;
@end

@implementation CKUIButtonWithInfo
@synthesize userInfo;
- (void)dealloc{
	[userInfo release];
	[super dealloc];
}
@end

@implementation CKNSObjectPropertyCellController

- (id)init{
	[super init];
	self.cellStyle = CKTableViewCellStyleValue3;
	return self;
}

-(void)dealloc{
	[super dealloc];
}


- (void)initTableViewCell:(UITableViewCell*)cell{
	[super initTableViewCell:cell];
}

- (void)setup{
	UITableViewCell* cell = self.tableViewCell;
	
	NSString* title = [[self.value class]description];
	if([self.value isKindOfClass:[CKObjectProperty class]]){
		CKObjectProperty* property = (CKObjectProperty*)self.value;
		title = [property name];
	}
	else{
		CKClassPropertyDescriptor* nameDescriptor = [self.value propertyDescriptorForKeyPath:@"modelName"];
		if(nameDescriptor != nil && [NSObject isKindOf:nameDescriptor.type parentType:[NSString class]]){
			title = [self.value valueForKeyPath:@"modelName"];
		}
	}
	
	id value = self.value;
	if([self.value isKindOfClass:[CKObjectProperty class]]){
		CKObjectProperty* property = (CKObjectProperty*)self.value;
		value = [property value];
	}
	
	if([value isKindOfClass:[CKDocumentCollection class]]
	   || [value isKindOfClass:[NSArray class]]){
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%d",[value count]];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		cell.accessoryView = nil;
	}
	else if(value == nil){
		cell.detailTextLabel.text = @"nil";
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		
		if([self.value isKindOfClass:[CKObjectProperty class]]){
			CKObjectProperty* property = (CKObjectProperty*)self.value;
			CKClassPropertyDescriptor* descriptor = [property descriptor];
			CKUIButtonWithInfo* button = [[[CKUIButtonWithInfo alloc]initWithFrame:CGRectMake(0,0,100,40)]autorelease];
			button.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithPointer:descriptor.type],@"class",property,@"property",nil];
			[button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
			[button setTitle:@"Create" forState:UIControlStateNormal];
			[button addTarget:self action:@selector(createObject:) forControlEvents:UIControlEventTouchUpInside];
			self.tableViewCell.accessoryView = button;
		}
	}
	else{
		cell.detailTextLabel.text = [value description];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		if([self.value isKindOfClass:[CKObjectProperty class]]){
			CKObjectProperty* property = (CKObjectProperty*)self.value;
			CKClassPropertyDescriptor* descriptor = [property descriptor];
			CKUIButtonWithInfo* button = [[[CKUIButtonWithInfo alloc]initWithFrame:CGRectMake(0,0,100,40)]autorelease];
			button.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithPointer:descriptor.type],@"class",property,@"property",nil];
			[button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
			[button setTitle:@"Delete" forState:UIControlStateNormal];
			[button addTarget:self action:@selector(deleteObject:) forControlEvents:UIControlEventTouchUpInside];
			self.tableViewCell.accessoryView = button;
		}
	}
	
	cell.textLabel.text = title;
}

- (void)setupCell:(UITableViewCell *)cell {
	[self clearBindingsContext];
	[super setupCell:cell];
	[self setup];
	
	if([self.value isKindOfClass:[CKObjectProperty class]]){
		CKObjectProperty* property = (CKObjectProperty*)self.value;
		id value = [property value];
		if(![value isKindOfClass:[CKDocumentCollection class]]){
			[self beginBindingsContextByRemovingPreviousBindings];
			[property.object bind:property.keyPath withBlock:^(id value){
				[self setup];
			}];
			[self endBindingsContext];
		}
	}
}

- (void)didSelectRow{
	id value = self.value;
	
	Class contentType = nil;
	if([self.value isKindOfClass:[CKObjectProperty class]]){
		CKObjectProperty* property = (CKObjectProperty*)self.value;
		CKClassPropertyDescriptor* descriptor = [property descriptor];
		
		CKModelObjectPropertyMetaData* metaData = [property metaData];
		contentType = [metaData contentType];
		
		//Wrap the array in a virtual collection
		if([NSObject isKindOf:descriptor.type parentType:[NSArray class]]){
			value = [CKObjectPropertyArrayCollection collectionWithArrayProperty:property];
		}		
		else{
			value = [property value];
		}
	}
	
	if([value isKindOfClass:[CKDocumentCollection class]]){
		NSMutableArray* mappings = [NSMutableArray array]; 
		[mappings mapControllerClass:[CKNSNumberPropertyCellController class] withObjectClass:[NSNumber class]];
		[mappings mapControllerClass:[CKNSStringPropertyCellController class] withObjectClass:[NSString class]];
		[mappings mapControllerClass:[CKNSObjectPropertyCellController class] withObjectClass:[NSObject class]];
		CKObjectTableViewController* controller = [[[CKObjectTableViewController alloc]initWithCollection:value mappings:mappings]autorelease];
		controller.title = self.tableViewCell.textLabel.text;
		if(contentType != nil){
			CKUIBarButtonItemWithInfo* button = [[[CKUIBarButtonItemWithInfo alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(createObject:)]autorelease];
			button.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:value,@"collection",[NSValue valueWithPointer:contentType],@"class",controller,@"controller",nil];
			controller.rightButton = button;
		}
		[self.parentController.navigationController pushViewController:controller animated:YES];
	}
	else{
		CKPropertyGridEditorController* propertyGrid = [[[CKPropertyGridEditorController alloc]initWithObject:value]autorelease];
		propertyGrid.title = self.tableViewCell.textLabel.text;
		[self.parentController.navigationController pushViewController:propertyGrid animated:YES];
	}
}

- (void)createObject:(id)sender{
	[self clearBindingsContext];
	
	id userInfos = nil;
	if([sender isKindOfClass:[CKUIButtonWithInfo class]]){
		CKUIButtonWithInfo* button = (CKUIButtonWithInfo*)sender;
		userInfos = button.userInfo;
	}
	else if([sender isKindOfClass:[CKUIBarButtonItemWithInfo class]]){
		CKUIBarButtonItemWithInfo* button = (CKUIBarButtonItemWithInfo*)sender;
		userInfos = button.userInfo;
	}
	
	Class type = [[userInfos objectForKey:@"class"]pointerValue];
	
	CKClassExplorer* controller = [[[CKClassExplorer alloc]initWithBaseClass:type]autorelease];
	controller.userInfo = userInfos;
	controller.delegate = self;
	[self.parentController.navigationController pushViewController:controller animated:YES];
}

- (void)deleteObject:(id)sender{
	CKUIButtonWithInfo* button = (CKUIButtonWithInfo*)sender;
	
	CKObjectProperty* property = [ button.userInfo objectForKey:@"property"];
	[property setValue:nil];
}

- (void)itemViewContainerController:(CKItemViewContainerController*)controller didSelectViewAtIndexPath:(NSIndexPath*)indexPath withObject:(id)object{
	CKClassExplorer* classExplorer = (CKClassExplorer*)controller;
	
	NSString* className = (NSString*)object;
	Class type = NSClassFromString(className);
	id instance = nil;
	if([NSObject isKindOf:type parentType:[UIView class]]){
		instance = [[[type alloc]initWithFrame:CGRectMake(0,0,100,100)]autorelease];
	}
	else{
		instance = [[[type alloc]init]autorelease];
	}
	
	CKDocumentCollection* collection = [classExplorer.userInfo objectForKey:@"collection"];
	if(collection){
		[collection addObjectsFromArray:[NSArray arrayWithObject:instance]];
	}
	else{
		CKObjectProperty* property = [classExplorer.userInfo objectForKey:@"property"];
		[property setValue:instance];
	}
	
	[controller.navigationController popViewControllerAnimated:YES];

	/*
	 NSIndexPath* indexPath = [controller indexPathForObject:object];
	 [controller.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
	 */
}

+ (NSValue*)viewSizeForObject:(id)object withParams:(NSDictionary*)params{
	return [NSValue valueWithCGSize:CGSizeMake(100,44)];
}

- (void)rotateCell:(UITableViewCell*)cell withParams:(NSDictionary*)params animated:(BOOL)animated{
	[super rotateCell:cell withParams:params animated:animated];
}

+ (CKItemViewFlags)flagsForObject:(id)object withParams:(NSDictionary*)params{
	id value = object;
	if([object isKindOfClass:[CKObjectProperty class]]){
		CKObjectProperty* property = (CKObjectProperty*)object;
		value = [property value];
	}
	
	if(value == nil){
		return CKItemViewFlagNone;
	}
	
	if([object isKindOfClass:[CKObjectProperty class]]){
		return CKItemViewFlagSelectable;
	}
	
	//TODO prendre en compte le readonly pour create/remove
	return CKItemViewFlagSelectable | CKItemViewFlagRemovable;
}

@end
