//
//  CKUIView+Style.m
//  CloudKit
//
//  Created by Sebastien Morel on 11-04-20.
//  Copyright 2011 WhereCloud Inc. All rights reserved.
//

#import "CKUIView+Style.h"
#import "CKStyles.h"
#import "CKStyleManager.h"
#import "CKStyle+Parsing.h"

#import "CKTableViewCellController+Style.h"
#import "CKUILabel+Style.h"
#import "CKUIImageView+Style.h"

NSString* CKStyleColor = @"color";
NSString* CKStyleGradientColors = @"gradientColors";
NSString* CKStyleGradientLocations = @"gradientLocations";
NSString* CKStyleImage = @"image";
NSString* CKStyleCornerStyle = @"cornerStyle";
NSString* CKStyleCornerSize = @"cornerSize";
NSString* CKStyleAlpha = @"alpha";

@implementation NSMutableDictionary (CKViewStyle)

- (UIColor*)color{
	return [self colorForKey:CKStyleColor];
}

- (NSArray*)gradientColors{
	return [self colorArrayForKey:CKStyleGradientColors];
}

- (NSArray*)gradientLocations{
	return [self cgFloatArrayForKey:CKStyleGradientLocations];
}

- (UIImage*)image{
	return [self imageForKey:CKStyleImage];
} 

- (CKViewCornerStyle)cornerStyle{
	return (CKViewCornerStyle)[self enumValueForKey:CKStyleCornerStyle 
									 withDictionary:CKEnumDictionary(CKViewCornerStyleDefault, CKViewCornerStyleRounded, CKViewCornerStylePlain)];
}

- (CGSize)cornerSize{
	return [self cgSizeForKey:CKStyleCornerSize];
}

- (CGFloat)alpha{
	return [self cgFloatForKey:CKStyleAlpha];
}

@end

@implementation UIView (CKStyle)

- (void)applyStyle:(NSMutableDictionary*)style{
	[self applyStyle:style propertyName:@""];
}

- (void)applyStyle:(NSMutableDictionary*)style propertyName:(NSString*)propertyName{
	[[self class] applyStyle:style toView:self propertyName:propertyName appliedStack:[NSMutableSet set]];
}

+ (CKGradientView*)gradientView:(UIView*)view{
	if([view isKindOfClass:[CKGradientView class]])
		return (CKGradientView*)view;
	
	for(UIView* subView in [view subviews]){
		if([subView isKindOfClass:[CKGradientView class]])
			return (CKGradientView*)subView;
	}
	return nil;
}

+ (BOOL)needSubView:(NSMutableDictionary*)style forView:(UIView*)view{
	BOOL isTableViewCell = [[view superview]isKindOfClass:[UITableViewCell class]];
	
	if(isTableViewCell
	   || [style containsObjectForKey:CKStyleGradientColors]
	   || [style containsObjectForKey:CKStyleCornerStyle]
	   || [style containsObjectForKey:CKStyleImage]){
		return YES;
	}
	return NO;
}

+ (BOOL)needSubView:(NSMutableDictionary*)style forView:(UIView*)view propertyName:(NSString*)propertyName{
	NSMutableDictionary* myViewStyle = [style styleForObject:view propertyName:propertyName];
	if([myViewStyle containsObjectForKey:CKStyleGradientColors]
	   || [myViewStyle containsObjectForKey:CKStyleCornerStyle]
	   || [myViewStyle containsObjectForKey:CKStyleImage]){
		return YES;
	}
	return NO;
}

+ (BOOL)applyStyle:(NSMutableDictionary*)style toView:(UIView*)view propertyName:(NSString*)propertyName appliedStack:(NSMutableSet*)appliedStack
                   delegate:(id)delegate {
	if(view == nil)
		return NO;
	
	NSMutableDictionary* myViewStyle = [style styleForObject:view propertyName:propertyName];
	if([appliedStack containsObject:view] == NO){
		//Apply before adding background subView
		[view applySubViewsStyle:myViewStyle appliedStack:appliedStack delegate:delegate];
		
		if(myViewStyle){
			if([myViewStyle isEmpty] == NO){
				UIView* backgroundView = view;
				BOOL opaque = YES;
				if([UIView needSubView:myViewStyle forView:view]){
					CKGradientView* gradientView = [UIView gradientView:view];
					if(gradientView == nil){
						gradientView = [[[CKGradientView alloc]initWithFrame:view.bounds]autorelease];
						gradientView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
						view.backgroundColor = [UIColor clearColor];
						[view insertSubview:gradientView atIndex:0];
					}
					
					if([myViewStyle containsObjectForKey:CKStyleImage]){
						gradientView.image = [myViewStyle image];
					}
					
					if([myViewStyle containsObjectForKey:CKStyleGradientColors]){
						NSArray* colors = [myViewStyle gradientColors];
						for(UIColor* color in colors){
							if(CGColorGetAlpha([color CGColor]) < 1){
								opaque = NO;
								break;
							}
						}
						gradientView.gradientColors = colors;
					}
					if([myViewStyle containsObjectForKey:CKStyleGradientLocations]){
						gradientView.gradientColorLocations = [myViewStyle gradientLocations];
					}
					
					//Apply corners
					CKViewCornerStyle cornerStyle = CKViewCornerStyleDefault;
					if([myViewStyle containsObjectForKey:CKStyleCornerStyle]){
						cornerStyle = [myViewStyle cornerStyle];
					}
					
					CKRoundedCornerViewType roundedCornerType = CKRoundedCornerViewTypeNone;
					if(delegate && [delegate respondsToSelector:@selector(view:cornerStyleWithStyle:)]){
						roundedCornerType = [delegate view:gradientView cornerStyleWithStyle:myViewStyle];
					}
					else{
						switch(cornerStyle){
							case CKViewCornerStyleRounded:{
								roundedCornerType = CKRoundedCornerViewTypeAll;
								break;
							}
						}
					}
					
					gradientView.corners = roundedCornerType;
					gradientView.backgroundColor = (opaque && roundedCornerType == CKRoundedCornerViewTypeNone) ? [UIColor blackColor] : [UIColor clearColor];
					
					if([myViewStyle containsObjectForKey:CKStyleCornerSize]){
						gradientView.roundedCornerSize = [myViewStyle cornerSize];
					}
					
					
					backgroundView = gradientView;
				}
				
				//Apply transparency
				if([myViewStyle containsObjectForKey:CKStyleAlpha]){
					backgroundView.alpha = [myViewStyle alpha];
				}
				
				//Apply color
				if([myViewStyle containsObjectForKey:CKStyleColor] == YES
				   && [myViewStyle containsObjectForKey:CKStyleGradientColors] == NO){
					if([backgroundView isKindOfClass:[CKGradientView class]]){
						CKGradientView* gradientView = (CKGradientView*)backgroundView;
						UIColor* color = [myViewStyle color];
						gradientView.gradientColors = [NSArray arrayWithObjects:color,color,nil];
						gradientView.gradientColorLocations = [NSArray arrayWithObjects:
															   [NSNumber numberWithInt:0], 
															   [NSNumber numberWithInt:1], 
															   nil];	
						opaque = opaque && (CGColorGetAlpha([color CGColor]) >= 1);				
					}
					else{
						backgroundView.backgroundColor = [myViewStyle color];
						opaque = opaque && (CGColorGetAlpha([backgroundView.backgroundColor CGColor]) >= 1);
					}
				}
				backgroundView.opaque = opaque && (backgroundView.alpha >= 1) ? YES : NO;
			}
			
			[appliedStack addObject:view];
		}
		return YES;
	}
	return NO;
}

+ (BOOL)applyStyle:(NSMutableDictionary*)style toView:(UIView*)view propertyName:(NSString*)propertyName appliedStack:(NSMutableSet*)appliedStack{
	return [[view class] applyStyle:style toView:view propertyName:propertyName appliedStack:appliedStack  delegate:nil];
}

@end

@implementation NSObject (CKStyle)

- (void)applySubViewsStyle:(NSMutableDictionary*)style appliedStack:(NSMutableSet*)appliedStack delegate:(id)delegate{
	//iterate on view properties to apply style using property names
	NSArray* properties = [self allPropertyDescriptors];
	for(CKClassPropertyDescriptor* descriptor in properties){
		if([NSObject isKindOf:descriptor.type parentType:[UIView class]]){
			UIView* view = [self valueForKey:descriptor.name];
			
			UIView* referenceView = (view != nil) ? view : (([self isKindOfClass:[UIView class]] == YES) ? (UIView*)self : nil);
			CGRect frame = (referenceView != nil) ? referenceView.bounds : CGRectMake(0,0,100,100);
			
			BOOL shouldReplaceView = NO;
			if(delegate && [delegate respondsToSelector:@selector(object:shouldReplaceViewWithDescriptor:)]){
				shouldReplaceView = [delegate object:self shouldReplaceViewWithDescriptor:descriptor];
			}
			
			//ICI ca chie car on remplace toutes les vues qui ont un style ...
			if([UIView needSubView:style forView:view propertyName:descriptor.name] && (view == nil || (shouldReplaceView && [view isKindOfClass:[CKGradientView class]] == NO)) ){
				view = [[[CKGradientView alloc]initWithFrame:frame]autorelease];
				view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
				[self setValue:view forKey:descriptor.name];
			}
			
			if(view){
				[descriptor.type applyStyle:style toView:view propertyName:descriptor.name appliedStack:appliedStack delegate:delegate];
			}
		}
	}
	
	if([self isKindOfClass:[UIView class]] == YES){
		UIView* selfView = (UIView*)self;
		for(UIView* view in [selfView subviews]){
			[[view class] applyStyle:style toView:view propertyName:@"" appliedStack:appliedStack delegate:delegate];
		}
	}
}

@end