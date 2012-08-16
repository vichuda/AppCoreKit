//
//  CKLayoutBox.m
//  AppCoreKit
//
//  Created by Sebastien Morel.
//  Copyright (c) 2012 WhereCloud Inc. All rights reserved.
//

#import "CKLayoutBox.h"
#import <objc/runtime.h>
#include <ext/hash_map>
#include <ext/hash_set>
#import <QuartzCore/QuartzCore.h>
#import "CKPropertyExtendedAttributes.h"
#import "CKStyleManager.h"
#import "CKRuntime.h"

using namespace __gnu_cxx;

namespace __gnu_cxx{
template<> struct hash< id >
{
    size_t operator()( id x) const{
        return (size_t)x;
    }
};
}

/**************************************************** Computation *************************************
 */

//CKLayout

@interface CKLayoutBox()
@property(nonatomic,assign,readwrite) UIView* containerLayoutView;
#ifdef LAYOUT_DEBUG_ENABLED
@property(nonatomic,assign,readwrite) UIView* debugView;
#endif
@end

@implementation CKLayoutBox
@synthesize maximumSize, minimumSize, margins, padding, layoutBoxes = _layoutBoxes,frame,containerLayoutBox,containerLayoutView = _containerLayoutView,verticalAlignment,horizontalAlignment,fixedSize,hidden,
maximumWidth,maximumHeight,minimumWidth,minimumHeight,fixedWidth,fixedHeight,marginLeft,marginTop,marginBottom,marginRight,paddingLeft,paddingTop,paddingBottom,paddingRight,
lastComputedSize,lastPreferedSize,invalidatedLayoutBlock = _invalidatedLayoutBlock;

#ifdef LAYOUT_DEBUG_ENABLED
@synthesize debugView;
#endif

- (id)init{
    self = [super init];
    [CKLayoutBox initializeBox:self];
    self.verticalAlignment = CKLayoutVerticalAlignmentCenter;
    self.horizontalAlignment = CKLayoutHorizontalAlignmentCenter;
    self.hidden = NO;
    
#ifdef LAYOUT_DEBUG_ENABLED  
    self.debugView = [[[UIView alloc]initWithFrame:CGRectMake(0,0,1,1)]autorelease];
    self.debugView.alpha = 0.4;
    self.debugView.backgroundColor = [UIColor redColor];
    self.debugView.layer.borderColor = [[UIColor redColor]CGColor];
    self.debugView.layer.borderWidth = 1;
#endif
    
#if TARGET_IPHONE_SIMULATOR
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateStylesheets) name:CKCascadingTreeFilesDidUpdateNotification object:nil];
#endif
    
    return self;
}

- (void)dealloc{
    
#if TARGET_IPHONE_SIMULATOR
    [[NSNotificationCenter defaultCenter] removeObserver:self name:CKCascadingTreeFilesDidUpdateNotification object:nil];
#endif
    
    [_layoutBoxes release];
    [_invalidatedLayoutBlock release];
    [super dealloc];
}

+ (void)invalidateLayoutBox:(NSObject<CKLayoutBoxProtocol>*)box recursivelly:(BOOL)recursivelly{
    box.lastComputedSize = CGSizeMake(0,0);
    box.lastPreferedSize = CGSizeMake(0,0);
    
    if(recursivelly){
        for(NSObject<CKLayoutBoxProtocol>* subbox in box.layoutBoxes){
            [CKLayoutBox invalidateLayoutBox:subbox recursivelly:YES];
        }
    }
}

- (void)updateStylesheets{
    if(self.containerLayoutBox == nil){
        [CKLayoutBox invalidateLayoutBox:self recursivelly:YES];
        [self.containerLayoutView setNeedsLayout];
    }
}

- (void)invalidateLayout{
    NSObject<CKLayoutBoxProtocol>* l = [self rootLayoutBox];
    if(l && !CGSizeEqualToSize(l.lastComputedSize, CGSizeMake(0,0))){
        [CKLayoutBox invalidateLayoutBox:l recursivelly:YES];
        [l.containerLayoutView setNeedsLayout];
        if(l.invalidatedLayoutBlock){
            l.invalidatedLayoutBlock(l);
        }
    }
}

- (NSObject<CKLayoutBoxProtocol>*)rootLayoutBox{
    NSObject<CKLayoutBoxProtocol>* l = self;
    while(l){
        if(l.containerLayoutBox){
            l = l.containerLayoutBox;
        }else return l;
    }
    return nil;
}

- (NSObject<CKLayoutBoxProtocol>*)previousVisibleBoxFromIndex:(NSInteger)index{
    NSInteger i = index;
    NSObject<CKLayoutBoxProtocol>* box = [self.layoutBoxes objectAtIndex:i];
    while(i > 0 && box && box.hidden){
        box = [self.layoutBoxes objectAtIndex:(--i)];
    }
    return box.hidden ? nil : box;
}

- (void)verticalAlignmentExtendedAttributes:(CKPropertyExtendedAttributes*)attributes{
    attributes.enumDescriptor = CKEnumDefinition(@"CKLayoutVerticalAlignment",
                                                 CKLayoutVerticalAlignmentTop,
                                                 CKLayoutVerticalAlignmentCenter,
                                                 CKLayoutVerticalAlignmentBottom);
}

- (void)horizontalAlignmentExtendedAttributes:(CKPropertyExtendedAttributes*)attributes{
    attributes.enumDescriptor = CKEnumDefinition(@"CKLayoutHorizontalAlignment",
                                                 CKLayoutHorizontalAlignmentLeft,
                                                 CKLayoutHorizontalAlignmentCenter,
                                                 CKLayoutHorizontalAlignmentRight);
}

+ (void)initializeBox:(NSObject<CKLayoutBoxProtocol>*)box{
    box.maximumSize = CGSizeMake(MAXFLOAT,MAXFLOAT);
    box.minimumSize = CGSizeMake(-MAXFLOAT,-MAXFLOAT);
    box.margins = UIEdgeInsetsMake(0, 0, 0, 0);
    box.padding = UIEdgeInsetsMake(0, 0, 0, 0);
}

+ (CGSize)preferedSizeConstraintToSize:(CGSize)size forBox:(NSObject<CKLayoutBoxProtocol>*)box{
    CGSize ret = size;
    
    if(box.minimumSize.width  > ret.width) {
        ret.width = box.minimumSize.width;
    }
    if(box.minimumSize.height > ret.height) {
        ret.height = box.minimumSize.height;
    }
    if(box.maximumSize.width  < ret.width) {
        ret.width = box.maximumSize.width;
    }
    if(box.maximumSize.height < ret.height) {
        ret.height = box.maximumSize.height;
    }
    
    return ret;
    //return CGSizeMake(ret.width + box.padding.right + box.padding.left,ret.height+box.padding.top + box.padding.bottom);
}

+ (void)performLayoutWithFrame:(CGRect)theframe forBox:(NSObject<CKLayoutBoxProtocol>*)box{
    for(NSObject<CKLayoutBoxProtocol>* subbox in box.layoutBoxes){
        CGRect boxframe = CGRectMake(theframe.origin.x/* + subbox.padding.left*/,
                                     theframe.origin.y/* + subbox.padding.top*/,
                                     MAX(0,theframe.size.width/* - (subbox.padding.left + subbox.padding.right)*/),
                                     MAX(0,theframe.size.height/* - (subbox.padding.top + subbox.padding.bottom)*/));
        [subbox performLayoutWithFrame:boxframe];
    }
}

+ (void)addLayoutBoxes:(NSArray*)boxes toBox:(NSObject<CKLayoutBoxProtocol>*)box{
    
#ifdef LAYOUT_DEBUG_ENABLED
    if([box isKindOfClass:[CKLayoutBox class]]){
        [[box containerLayoutView] addSubview:((CKLayoutBox*)box).debugView];
    }
#endif
    
    for(NSObject<CKLayoutBoxProtocol>* subBox in boxes){
        subBox.containerLayoutBox = box;
        if([subBox isKindOfClass:[CKLayoutBox class]]){
            ((CKLayoutBox*)subBox).containerLayoutView = [box containerLayoutView];
        }else if([subBox isKindOfClass:[UIView class]]){
            UIView* view = (UIView*)subBox;
            view.autoresizingMask = 0;
            if([view superview] != [box containerLayoutView]){
                if([view stylesheet] == nil){
                    NSMutableDictionary* stylesheet = [[box containerLayoutView] stylesheet];
                    [view findAndApplyStylesheetFromStylesheet:stylesheet propertyName:nil];
                }
                [[box containerLayoutView]addSubview:view];
            }
        }
    }
}

+ (void)removeViewsFromBox:(NSObject<CKLayoutBoxProtocol>*)box recursively:(BOOL)recursively{ 
    
#ifdef LAYOUT_DEBUG_ENABLED
    if([box isKindOfClass:[CKLayoutBox class]]){
        [((CKLayoutBox*)box).debugView removeFromSuperview];
    }
#endif
    
    for(NSObject<CKLayoutBoxProtocol>* subBox in [box layoutBoxes]){
        if([subBox isKindOfClass:[CKLayoutBox class]]){
            [CKLayoutBox removeViewsFromBox:subBox recursively:YES];
        }else if([subBox isKindOfClass:[UIView class]]){
            UIView* view = (UIView*)subBox;
            [view removeFromSuperview];
        }
    } 
}

+ (void)removeLayoutBoxes:(NSArray*)boxes fromBox:(NSObject<CKLayoutBoxProtocol>*)box{
    for(NSObject<CKLayoutBoxProtocol>* subBox in boxes){
        if(subBox.containerLayoutBox == box){
            subBox.containerLayoutBox = nil;
            if([subBox isKindOfClass:[CKLayoutBox class]]){
                ((CKLayoutBox*)subBox).containerLayoutView = nil;
            }
        }
    } 
    [CKLayoutBox removeViewsFromBox:box recursively:YES];
}

- (void)setContainerLayoutView:(UIView*)view{
    if(_containerLayoutView != view){
        _containerLayoutView = view;
        
#ifdef LAYOUT_DEBUG_ENABLED
        [_containerLayoutView addSubview:self.debugView];
#endif
        
        for(NSObject<CKLayoutBoxProtocol>* subBox in self.layoutBoxes){
            if([subBox isKindOfClass:[CKLayoutBox class]]){
                ((CKLayoutBox*)subBox).containerLayoutView = [self containerLayoutView];
            }else if([subBox isKindOfClass:[UIView class]]){
                UIView* view = (UIView*)subBox;
                if([view superview] != [self containerLayoutView]){
                    if([view stylesheet] == nil){
                        NSMutableDictionary* stylesheet = [[self containerLayoutView] stylesheet];
                        [view findAndApplyStylesheetFromStylesheet:stylesheet  propertyName:nil];
                    }
                    [[self containerLayoutView]addSubview:view];
                }
            }
        }
    }
}

- (CGSize)preferedSizeConstraintToSize:(CGSize)size{
    if(CGSizeEqualToSize(size, self.lastComputedSize))
        return self.lastPreferedSize;
    self.lastComputedSize = size;
    
    self.lastPreferedSize = [CKLayoutBox preferedSizeConstraintToSize:size forBox:self];
    return self.lastPreferedSize;
}

- (void)performLayoutWithFrame:(CGRect)theframe{
    CGSize size = [self preferedSizeConstraintToSize:theframe.size];
    self.frame = CGRectMake(theframe.origin.x,theframe.origin.y,size.width,size.height);
    
    [CKLayoutBox performLayoutWithFrame:self.frame forBox:self];
    
#ifdef LAYOUT_DEBUG_ENABLED    
    self.debugView.frame = self.frame;
#endif
}

- (void)setLayoutBoxes:(NSArray*)boxes{
    if(_layoutBoxes){
        [CKLayoutBox removeLayoutBoxes:_layoutBoxes fromBox:self];
    }
    
    [_layoutBoxes release];
    _layoutBoxes = [boxes retain];
    
    if(_layoutBoxes){
        [CKLayoutBox addLayoutBoxes:_layoutBoxes toBox:self];
    }
}

- (void)setFixedSize:(CGSize)size{
    self.maximumSize = size;
    self.minimumSize = size;
}

- (CGSize)fixedSize{
    if(CGSizeEqualToSize(self.maximumSize, self.minimumSize)){
        return self.minimumSize;
    }
    return CGSizeMake(MAXFLOAT, MAXFLOAT);
}


- (void)setMaximumWidth:(CGFloat)f  { self.maximumSize = CGSizeMake(f,self.maximumSize.height); }
- (void)setMaximumHeight:(CGFloat)f { self.maximumSize = CGSizeMake(self.maximumSize.width,f); }
- (void)setMinimumWidth:(CGFloat)f  { self.minimumSize = CGSizeMake(f,self.minimumSize.height); }
- (void)setMinimumHeight:(CGFloat)f { self.minimumSize = CGSizeMake(self.minimumSize.width,f); }
- (void)setFixedWidth:(CGFloat)f    { self.maximumWidth = f; self.minimumWidth = f; }
- (void)setFixedHeight:(CGFloat)f   { self.maximumHeight = f; self.minimumHeight = f; }
- (void)setMarginLeft:(CGFloat)f    { UIEdgeInsets insets = self.margins; insets.left = f; self.margins = insets; }
- (void)setMarginTop:(CGFloat)f     { UIEdgeInsets insets = self.margins; insets.top = f; self.margins = insets; }
- (void)setMarginBottom:(CGFloat)f  { UIEdgeInsets insets = self.margins; insets.bottom = f; self.margins = insets; }
- (void)setMarginRight:(CGFloat)f   { UIEdgeInsets insets = self.margins; insets.right = f; self.margins = insets; }
- (void)setPaddingLeft:(CGFloat)f   { UIEdgeInsets insets = self.padding; insets.left = f; self.padding = insets; }
- (void)setPaddingTop:(CGFloat)f    { UIEdgeInsets insets = self.padding; insets.top = f; self.padding = insets; }
- (void)setPaddingBottom:(CGFloat)f { UIEdgeInsets insets = self.padding; insets.bottom = f; self.padding = insets; }
- (void)setPaddingRight:(CGFloat)f  { UIEdgeInsets insets = self.padding; insets.right = f; self.padding = insets; }


- (CGFloat)maximumWidth  { return self.maximumSize.width; }
- (CGFloat)maximumHeight { return self.maximumSize.height; }
- (CGFloat)minimumWidth  { return self.minimumSize.width; }
- (CGFloat)minimumHeight { return self.minimumSize.height; }
- (CGFloat)fixedWidth    { return (self.maximumWidth == self.minimumWidth) ? self.maximumWidth : MAXFLOAT; }
- (CGFloat)fixedHeight   { return (self.maximumHeight == self.minimumHeight) ? self.maximumHeight : MAXFLOAT; }
- (CGFloat)marginLeft    { return self.margins.left; }
- (CGFloat)marginTop     { return self.margins.top; }
- (CGFloat)marginBottom  { return self.margins.bottom; }
- (CGFloat)marginRight   { return self.margins.right; }
- (CGFloat)paddingLeft   { return self.padding.left; }
- (CGFloat)paddingTop    { return self.padding.top; }
- (CGFloat)paddingBottom { return self.padding.bottom; }
- (CGFloat)paddingRight  { return self.padding.right; }

@end

//UIView

@implementation UIView (Layout)
@dynamic  maximumSize, minimumSize, margins, padding, layoutBoxes,frame,containerLayoutBox,containerLayoutView,fixedSize,hidden,
maximumWidth,maximumHeight,minimumWidth,minimumHeight,fixedWidth,fixedHeight,marginLeft,marginTop,marginBottom,marginRight,paddingLeft,paddingTop,paddingBottom,paddingRight,
lastComputedSize,lastPreferedSize,invalidatedLayoutBlock;

- (CGSize)preferedSizeConstraintToSize:(CGSize)size{
    if(CGSizeEqualToSize(size, self.lastComputedSize))
        return self.lastPreferedSize;
    self.lastComputedSize = size;
    
    if(self.layoutBoxes && [self.layoutBoxes count] > 0){
        CGFloat maxWidth = 0;
        CGFloat maxHeight = 0;
        
        for(NSObject<CKLayoutBoxProtocol>* box in self.layoutBoxes){
            CGSize constraint = size;
            
            CGSize s = [box preferedSizeConstraintToSize:constraint];
            
            if(s.width > maxWidth) maxWidth = s.width;
            if(s.height > maxHeight) maxHeight = s.height;
        }
        
        size = CGSizeMake(maxWidth,maxHeight);
    }
    
    size = [CKLayoutBox preferedSizeConstraintToSize:size forBox:self];
    
    self.lastPreferedSize = CGSizeMake(size.width + self.padding.left + self.padding.right,size.height + self.padding.top + self.padding.bottom);
    return self.lastPreferedSize;
}

- (void)performLayoutWithFrame:(CGRect)theframe{
    CGSize size = [self preferedSizeConstraintToSize:theframe.size];
    CGRect frame = CGRectMake(theframe.origin.x,theframe.origin.y,size.width,size.height);
    
    //If the view has its own layout, the sub boxes are placed relative to it !
    if(self.layoutBoxes && [self.layoutBoxes count] > 0){
        frame = CGRectMake(0,0,frame.size.width,frame.size.height);
    }
    
    [CKLayoutBox performLayoutWithFrame:frame forBox:self];
}

- (void)invalidateLayout{
    NSObject<CKLayoutBoxProtocol>* l = [self rootLayoutBox];
    if(l && !CGSizeEqualToSize(l.lastComputedSize, CGSizeMake(0,0))){
        [CKLayoutBox invalidateLayoutBox:l recursivelly:YES];
        [l.containerLayoutView setNeedsLayout];
        if(l.invalidatedLayoutBlock){
            l.invalidatedLayoutBlock(l);
        }
    }
}

- (NSObject<CKLayoutBoxProtocol>*)rootLayoutBox{
    NSObject<CKLayoutBoxProtocol>* l = self;
    while(l){
        if(l.containerLayoutBox){
            l = l.containerLayoutBox;
        }else return l;
    }
    return nil;
}

@end

//CKLayoutFlexibleSpace

@implementation CKLayoutFlexibleSpace

- (id)init{
    self = [super init];
    
#ifdef LAYOUT_DEBUG_ENABLED    
    self.debugView.backgroundColor = [UIColor blueColor];
    self.debugView.layer.borderColor = [[UIColor blueColor]CGColor];
    self.debugView.layer.borderWidth = 1;
#endif
    
    return self;
}

- (CGSize)preferedSizeConstraintToSize:(CGSize)size{
    if(CGSizeEqualToSize(size, self.lastComputedSize))
        return self.lastPreferedSize;
    self.lastComputedSize = size;
    
    if([self.containerLayoutBox isKindOfClass:[CKHorizontalBoxLayout class]])
        self.lastPreferedSize = [CKLayoutBox preferedSizeConstraintToSize:CGSizeMake(size.width,1) forBox:self];
    else if([self.containerLayoutBox isKindOfClass:[CKVerticalBoxLayout class]])
        self.lastPreferedSize = [CKLayoutBox preferedSizeConstraintToSize:CGSizeMake(1,size.height) forBox:self];
    
    return self.lastPreferedSize;
}

- (void)performLayoutWithFrame:(CGRect)theframe{
    self.frame = theframe;
    
#ifdef LAYOUT_DEBUG_ENABLED    
    self.debugView.frame = self.frame;
#endif
}

@end


//CKVerticalBoxLayout

@implementation CKVerticalBoxLayout

- (CGSize)preferedSizeConstraintToSize:(CGSize)size{
    if([self.layoutBoxes count] <= 0)
        return CGSizeMake(0,0);
    
    size = [CKLayoutBox preferedSizeConstraintToSize:size forBox:self];
    size = CGSizeMake(size.width - self.padding.left - self.padding.right,size.height - self.padding.top - self.padding.bottom);
    
    if(CGSizeEqualToSize(size, self.lastComputedSize))
        return self.lastPreferedSize;
    self.lastComputedSize = size;
    
    BOOL includesFlexispaces = (size.height < MAXFLOAT);
    
    CGFloat maxHeight = 0;
    CGFloat maxWidth = 0;
    
    if([self.layoutBoxes count] > 0){
        
        //Compute flexible height
        CGFloat flexibleHeight = size.height;
        NSInteger flexibleCount = 0;
        NSInteger numberOfFlexiSpaces = NO;
        hash_set<id> appliedMargins;
        for(int i =0;i < [self.layoutBoxes count]; ++i){
            NSObject<CKLayoutBoxProtocol>* box = [self.layoutBoxes objectAtIndex:i];
            if(!box.hidden){
                if([box isKindOfClass:[CKLayoutFlexibleSpace class]] && !includesFlexispaces){}
                else if([box isKindOfClass:[CKLayoutBox class]] && ![box isKindOfClass:[CKLayoutFlexibleSpace class]] && [[box layoutBoxes]count] <= 0){}
                else{
                    if([box isKindOfClass:[CKLayoutFlexibleSpace class]]){
                        numberOfFlexiSpaces++;
                        flexibleCount++;
                        appliedMargins.insert(box);
                    }
                    else {
                        if(box.maximumSize.height == box.minimumSize.height){ //fixed size
                            flexibleHeight -= box.maximumSize.height;
                        }else{
                            flexibleCount++;
                        }
                        
                        CGFloat topMargin = 0;
                        if(i > 0){
                            NSObject<CKLayoutBoxProtocol>* boxBottom = [self previousVisibleBoxFromIndex:i-1];
                            if(boxBottom && ![boxBottom isKindOfClass:[CKLayoutFlexibleSpace class]]){
                                topMargin = MAX(box.margins.top,boxBottom.margins.bottom);
                            }else if(appliedMargins.find(boxBottom) == appliedMargins.end()){
                                topMargin = box.margins.top;
                            }
                        }else{
                            topMargin = box.margins.top;
                        }
                        appliedMargins.insert(box);
                        
                        flexibleHeight -= topMargin;
                    }
                }
            }
        }
        
        NSObject<CKLayoutBoxProtocol>* lastBox = [self previousVisibleBoxFromIndex:[self.layoutBoxes count] - 1];
        if(lastBox){
            flexibleHeight -= lastBox.margins.bottom;
        }
        
        //Adjust Flexible boxes using minimum/maximum sizes
        hash_map<id, CGSize> precomputedSize;
        CGFloat flexibleSizeToRemove = 0;
        NSInteger flexibleCountToRemove = 0;
        
        for(int i =0;i < [self.layoutBoxes count]; ++i){
            NSObject<CKLayoutBoxProtocol>* box = [self.layoutBoxes objectAtIndex:i];
            if(!box.hidden){
                if([box isKindOfClass:[CKLayoutFlexibleSpace class]]){
                }
                else if([box isKindOfClass:[CKLayoutBox class]] && [[box layoutBoxes]count] <= 0){}
                else{
                    CGFloat width = MIN(size.width - box.margins.left - box.margins.right,box.maximumSize.width);
                    
                    CGSize subsize = CGSizeMake(0,0);
                    if(box.maximumSize.height == box.minimumSize.height){ //fixed size
                        precomputedSize[box] = CGSizeMake(width,box.minimumSize.height);
                    }else{
                        CGFloat preferedHeight = flexibleHeight / (flexibleCount - numberOfFlexiSpaces);
                        subsize = [box preferedSizeConstraintToSize:CGSizeMake(width,preferedHeight)];
                        if( numberOfFlexiSpaces > 0
                           || (subsize.height < preferedHeight && box.maximumSize.height == MAXFLOAT)
                           || (subsize.height <= preferedHeight && box.maximumSize.height == subsize.height)){
                            precomputedSize[box] = subsize;
                            flexibleSizeToRemove += subsize.height;
                            flexibleCountToRemove++;
                            
                            flexibleHeight -= subsize.height;
                            flexibleCount -= 1;
                        }
                    }
                }
            }
        }
        
        //Compute layout
        CGFloat y = 0;
        appliedMargins.clear();
        for(int i =0;i < [self.layoutBoxes count]; ++i){
            NSObject<CKLayoutBoxProtocol>* box = [self.layoutBoxes objectAtIndex:i];
            if(!box.hidden){
                if([box isKindOfClass:[CKLayoutFlexibleSpace class]] && !includesFlexispaces){}
                else if([box isKindOfClass:[CKLayoutBox class]] && ![box isKindOfClass:[CKLayoutFlexibleSpace class]] && [[box layoutBoxes]count] <= 0){}
                else{
                    if(![box isKindOfClass:[CKLayoutFlexibleSpace class]]){
                        CGFloat topMargin = 0;
                        if(i > 0){
                            NSObject<CKLayoutBoxProtocol>* boxBottom = [self previousVisibleBoxFromIndex:i-1];
                            if(boxBottom && ![boxBottom isKindOfClass:[CKLayoutFlexibleSpace class]]){
                                topMargin = MAX(box.margins.top,boxBottom.margins.bottom);
                            }else if(appliedMargins.find(boxBottom) == appliedMargins.end()){
                                topMargin = box.margins.top;
                            }
                        }else{
                            topMargin = box.margins.top;
                        }                   
                        y += topMargin;
                    }
                    appliedMargins.insert(box); 
                    
                    CGSize subsize = CGSizeMake(0,0);
                    hash_map<id, CGSize>::iterator it = precomputedSize.find(box);
                    if(it != precomputedSize.end()){
                        subsize = it->second;
                        box.lastComputedSize = subsize;
                        box.lastPreferedSize = subsize;
                    }else{
                        CGFloat width = MIN(size.width - box.margins.left - box.margins.right,box.maximumSize.width);
                        
                        subsize = [box preferedSizeConstraintToSize:CGSizeMake(width,flexibleHeight / flexibleCount)];
                        flexibleHeight -= subsize.height;
                        flexibleCount--;
                    }
                    
                    CGFloat totalWidth = box.margins.left + box.margins.right + subsize.width;
                    if(maxWidth < totalWidth) maxWidth = totalWidth;
                    
                    y += subsize.height;
                }
            }
            
            maxHeight = y + lastBox.margins.bottom;
        }
    }
    
    CGSize ret = [CKLayoutBox preferedSizeConstraintToSize:CGSizeMake(MIN(maxWidth,size.width),MIN(maxHeight,size.height)) forBox:self];
    self.lastPreferedSize = [CKLayoutBox preferedSizeConstraintToSize:CGSizeMake(ret.width + self.padding.left + self.padding.right,
                                                                                 ret.height + self.padding.bottom + self.padding.top) 
                                                               forBox:self];
    return self.lastPreferedSize;
}

- (void)performLayoutWithFrame:(CGRect)theframe{
    CGSize size = [self preferedSizeConstraintToSize:theframe.size];
    self.frame = CGRectMake(theframe.origin.x,theframe.origin.y,size.width,size.height);
    
    
#ifdef LAYOUT_DEBUG_ENABLED
    self.debugView.frame = self.frame;
#endif
    
    if([self.layoutBoxes count] > 0){

        //Compute layout
        CGFloat y = self.frame.origin.y + self.padding.top;
        hash_set<id> appliedMargins;
        for(int i =0;i < [self.layoutBoxes count]; ++i){
            NSObject<CKLayoutBoxProtocol>* box = [self.layoutBoxes objectAtIndex:i];
            if(!box.hidden){
                if([box isKindOfClass:[CKLayoutBox class]] && ![box isKindOfClass:[CKLayoutFlexibleSpace class]] && [[box layoutBoxes]count] <= 0){}
                else{
                    if(![box isKindOfClass:[CKLayoutFlexibleSpace class]]){
                        CGFloat topMargin = 0;
                        if(i > 0){
                            NSObject<CKLayoutBoxProtocol>* boxBottom = [self previousVisibleBoxFromIndex:i-1];
                            if(boxBottom && ![boxBottom isKindOfClass:[CKLayoutFlexibleSpace class]]){
                                topMargin = MAX(box.margins.top,boxBottom.margins.bottom);
                            }else if(appliedMargins.find(boxBottom) == appliedMargins.end()){
                                topMargin = box.margins.top;
                            }
                        }else{
                            topMargin = box.margins.top;
                        }                 
                        y += topMargin;
                    }
                    appliedMargins.insert(box);   
                    
                    CGSize subsize = box.lastPreferedSize;
                    
                    CGRect boxframe = CGRectMake(box.margins.left,y,MAX(0,subsize.width),MAX(0,subsize.height));
                    box.frame = CGRectIntegral(boxframe);
                    
                    y += subsize.height;
                }
            }
        }
        
        NSObject<CKLayoutBoxProtocol>* lastBox = [self previousVisibleBoxFromIndex:[self.layoutBoxes count] - 1];
        CGFloat totalHeight = y + (lastBox ? lastBox.margins.bottom : 0) - (self.frame.origin.y);
        
        //Handle Vertical alignment
        CGFloat totalWidth = (size.width - self.padding.left - self.padding.right);
        
        for(int i =0;i < [self.layoutBoxes count]; ++i){
            NSObject<CKLayoutBoxProtocol>* box = [self.layoutBoxes objectAtIndex:i]; 
            if(!box.hidden){
                if([box isKindOfClass:[CKLayoutBox class]] && ![box isKindOfClass:[CKLayoutFlexibleSpace class]] && [[box layoutBoxes]count] <= 0){}
                else{
                    CGFloat offsetX = self.frame.origin.x + self.padding.left;
                    CGFloat offsetY = 0;
                    switch(self.horizontalAlignment){
                        case CKLayoutHorizontalAlignmentLeft:break; //this is already computed
                        case CKLayoutHorizontalAlignmentRight: offsetX += totalWidth - box.frame.size.width; break;
                        case CKLayoutVerticalAlignmentCenter:  offsetX += (totalWidth / 2) - (box.frame.size.width / 2); break; 
                    }
                    
                    if(totalHeight < (size.height - self.padding.top - self.padding.bottom)){
                        switch(self.verticalAlignment){
                            case CKLayoutVerticalAlignmentTop: break; //default behaviour
                            case CKLayoutVerticalAlignmentCenter:  offsetY = (size.height - totalHeight) / 2; break;
                            case CKLayoutVerticalAlignmentBottom: offsetY = size.height - totalHeight; break;
                        }
                    }
                    
                    box.frame = CGRectIntegral(CGRectMake(box.frame.origin.x + offsetX,box.frame.origin.y + offsetY,box.frame.size.width,box.frame.size.height));
                    [box performLayoutWithFrame:box.frame];
                }
            }
        }
    }
}

@end

//CKHorizontalBoxLayout

@implementation CKHorizontalBoxLayout

- (CGSize)preferedSizeConstraintToSize:(CGSize)size{
    if([self.layoutBoxes count] <= 0)
        return CGSizeMake(0,0);
    
    size = [CKLayoutBox preferedSizeConstraintToSize:size forBox:self];
    size = CGSizeMake(size.width - self.padding.left - self.padding.right,size.height - self.padding.top - self.padding.bottom);
    
    if(CGSizeEqualToSize(size, self.lastComputedSize))
        return self.lastPreferedSize;
    self.lastComputedSize = size;
    
    
    BOOL includesFlexispaces = (size.width < MAXFLOAT);
    
    CGFloat maxHeight = 0;
    CGFloat maxWidth = 0;
    
    if([self.layoutBoxes count] > 0){
        
        //Compute flexible width
        CGFloat flexiblewidth = size.width;
        NSInteger flexibleCount = 0;
        NSInteger numberOfFlexiSpaces = NO;
        hash_set<id> appliedMargins;
        for(int i =0;i < [self.layoutBoxes count]; ++i){
            NSObject<CKLayoutBoxProtocol>* box = [self.layoutBoxes objectAtIndex:i]; 
            
            if(!box.hidden){
                if([box isKindOfClass:[CKLayoutFlexibleSpace class]] && !includesFlexispaces){}
                else if([box isKindOfClass:[CKLayoutBox class]] && ![box isKindOfClass:[CKLayoutFlexibleSpace class]] && [[box layoutBoxes]count] <= 0){}
                else{
                    if([box isKindOfClass:[CKLayoutFlexibleSpace class]]){
                        numberOfFlexiSpaces++;
                        flexibleCount++;
                        appliedMargins.insert(box);
                    }else{
                        if(box.maximumSize.width == box.minimumSize.width){ //fixed size
                            flexiblewidth -= box.maximumSize.width;
                        }else{
                            flexibleCount++;
                        }
                        
                        CGFloat leftMargin = 0;
                        if(i > 0){
                            NSObject<CKLayoutBoxProtocol>* boxLeft = [self previousVisibleBoxFromIndex:i-1];
                            if(boxLeft && ![boxLeft isKindOfClass:[CKLayoutFlexibleSpace class]]){
                                leftMargin = MAX(box.margins.left,boxLeft.margins.right);
                            }else if(appliedMargins.find(boxLeft) == appliedMargins.end()){
                                leftMargin = box.margins.left;
                            }
                        }else{
                            leftMargin = box.margins.left;
                        }
                        appliedMargins.insert(box);
                        
                        flexiblewidth -= leftMargin;
                    }
                }
            }
        }
        
        NSObject<CKLayoutBoxProtocol>* lastBox = [self previousVisibleBoxFromIndex:[self.layoutBoxes count] - 1];
        if(lastBox){
            flexiblewidth -= lastBox.margins.right;
        }
        
        //Adjust Flexible boxes using minimum/maximum sizes
        hash_map<id, CGSize> precomputedSize;
        CGFloat flexibleSizeToRemove = 0;
        NSInteger flexibleCountToRemove = 0;
        
        for(int i =0;i < [self.layoutBoxes count]; ++i){
            NSObject<CKLayoutBoxProtocol>* box = [self.layoutBoxes objectAtIndex:i];
            if(!box.hidden){
                if([box isKindOfClass:[CKLayoutFlexibleSpace class]]){
                }
                else if([box isKindOfClass:[CKLayoutBox class]] && [[box layoutBoxes]count] <= 0){}
                else{
                    
                    CGFloat height = MIN(size.height - box.margins.top - box.margins.bottom,box.maximumSize.height);
                    
                    CGSize subsize = CGSizeMake(0,0);
                    if(box.maximumSize.width == box.minimumSize.width){ //fixed size
                        precomputedSize[box] = CGSizeMake(box.minimumSize.width,height);
                    }else{
                        CGFloat preferedWidth = flexiblewidth / (flexibleCount - numberOfFlexiSpaces);
                        subsize = [box preferedSizeConstraintToSize:CGSizeMake(preferedWidth,height)];
                        
                        if( numberOfFlexiSpaces > 0
                           || (subsize.width < preferedWidth && box.maximumSize.width == MAXFLOAT)
                           || (subsize.width <= preferedWidth && box.maximumSize.width == subsize.width)){
                            precomputedSize[box] = subsize;
                            flexibleSizeToRemove += subsize.width;
                            flexibleCountToRemove++;
                            
                            
                            flexiblewidth -= subsize.width;
                            flexibleCount -= 1;
                        }
                    }
                }
            }
        }
        
        //Compute layout
        CGFloat x =  0;
        appliedMargins.clear();
        for(int i =0;i < [self.layoutBoxes count]; ++i){
            NSObject<CKLayoutBoxProtocol>* box = [self.layoutBoxes objectAtIndex:i];
            if(!box.hidden){
                if([box isKindOfClass:[CKLayoutFlexibleSpace class]] && !includesFlexispaces){}
                else if([box isKindOfClass:[CKLayoutBox class]] && ![box isKindOfClass:[CKLayoutFlexibleSpace class]] && [[box layoutBoxes]count] <= 0){}
                else{
                    if(![box isKindOfClass:[CKLayoutFlexibleSpace class]]){
                        CGFloat leftMargin = 0;
                        if(i > 0){
                            NSObject<CKLayoutBoxProtocol>* boxLeft = [self previousVisibleBoxFromIndex:i-1];
                            if(boxLeft && ![boxLeft isKindOfClass:[CKLayoutFlexibleSpace class]]){
                                leftMargin = MAX(box.margins.left,boxLeft.margins.right);
                            }else if(appliedMargins.find(boxLeft) == appliedMargins.end()){
                                leftMargin = box.margins.left;
                            }
                        }else{
                            leftMargin = box.margins.left;
                        }
                        
                        x += leftMargin;
                    }
                    appliedMargins.insert(box);
                    
                    CGSize subsize = CGSizeMake(0,0);
                    hash_map<id, CGSize>::iterator it = precomputedSize.find(box);
                    if(it != precomputedSize.end()){
                        subsize = it->second;
                        box.lastComputedSize = subsize;
                        box.lastPreferedSize = subsize;
                    }else{
                        CGFloat height = MIN(size.height - box.margins.top - box.margins.bottom,box.maximumSize.height);
                        
                        subsize = [box preferedSizeConstraintToSize:CGSizeMake(flexiblewidth / flexibleCount,height)];
                        flexiblewidth -= subsize.width;
                        flexibleCount--;
                    }
            
                    CGFloat totalHeight = box.margins.top + box.margins.bottom + subsize.height;
                    if(maxHeight < totalHeight) maxHeight = totalHeight;
                    
                    x += subsize.width;
                }
            }
            
            maxWidth = x + lastBox.margins.right;
        }
    }
    
    
    CGSize ret = [CKLayoutBox preferedSizeConstraintToSize:CGSizeMake(MIN(maxWidth,size.width),MIN(maxHeight,size.height)) forBox:self];
    self.lastPreferedSize = [CKLayoutBox preferedSizeConstraintToSize:CGSizeMake(ret.width + self.padding.left + self.padding.right,
                                                                                 ret.height + self.padding.bottom + self.padding.top) 
                                                               forBox:self];
    return self.lastPreferedSize;
}

- (void)performLayoutWithFrame:(CGRect)theframe{
    CGSize size = [self preferedSizeConstraintToSize:theframe.size];
    self.frame = CGRectMake(theframe.origin.x,theframe.origin.y,size.width,size.height);
    
#ifdef LAYOUT_DEBUG_ENABLED
    self.debugView.frame = self.frame;
#endif
       
    if([self.layoutBoxes count] > 0){
        //Compute layout
        CGFloat x =  self.frame.origin.x + self.padding.left;
        hash_set<id> appliedMargins;
        for(int i =0;i < [self.layoutBoxes count]; ++i){
            NSObject<CKLayoutBoxProtocol>* box = [self.layoutBoxes objectAtIndex:i];
            if(!box.hidden){
                if([box isKindOfClass:[CKLayoutBox class]] && ![box isKindOfClass:[CKLayoutFlexibleSpace class]] && [[box layoutBoxes]count] <= 0){}
                else{
                    if(![box isKindOfClass:[CKLayoutFlexibleSpace class]]){
                        CGFloat leftMargin = 0;
                        if(i > 0){
                            NSObject<CKLayoutBoxProtocol>* boxLeft = [self previousVisibleBoxFromIndex:i-1];
                            if(boxLeft && ![boxLeft isKindOfClass:[CKLayoutFlexibleSpace class]]){
                                leftMargin = MAX(box.margins.left,boxLeft.margins.right);
                            }else if(appliedMargins.find(boxLeft) == appliedMargins.end()){
                                leftMargin = box.margins.left;
                            }
                        }else{
                            leftMargin = box.margins.left;
                        }
                        
                        x += leftMargin;
                    }
                    appliedMargins.insert(box);
                    
                    CGSize subsize = box.lastPreferedSize;
                    
                    CGRect boxframe = CGRectMake(x,box.margins.top,MAX(0,subsize.width),MAX(0,subsize.height));
                    box.frame = CGRectIntegral(boxframe);
                    
                    x += subsize.width;
                }
            }
        }
        
        
        NSObject<CKLayoutBoxProtocol>* lastBox = [self previousVisibleBoxFromIndex:[self.layoutBoxes count] - 1];
        CGFloat totalWidth = x + (lastBox ? lastBox.margins.right : 0) -  self.frame.origin.x;
        
        //Handle Horizontal alignment
        CGFloat totalHeight = (size.height - self.padding.top - self.padding.bottom);
        
        for(int i =0;i < [self.layoutBoxes count]; ++i){
            NSObject<CKLayoutBoxProtocol>* box = [self.layoutBoxes objectAtIndex:i];
            if(!box.hidden){
                if([box isKindOfClass:[CKLayoutBox class]] && ![box isKindOfClass:[CKLayoutFlexibleSpace class]] && [[box layoutBoxes]count] <= 0){}
                else{
                    
                    CGFloat offsetX = 0;
                    CGFloat offsetY = self.frame.origin.y + self.padding.top;
                    switch(self.verticalAlignment){
                        case CKLayoutVerticalAlignmentTop:break; //this is already computed
                        case CKLayoutVerticalAlignmentBottom: offsetY += totalHeight - box.frame.size.height; break; //this is already computed
                        case CKLayoutVerticalAlignmentCenter: offsetY += (totalHeight  / 2) - (box.frame.size.height / 2); break; //this is already computed
                    }
                    
                    
                    if(totalWidth < (size.width - self.padding.left - self.padding.right)){
                        switch(self.horizontalAlignment){
                            case CKLayoutHorizontalAlignmentLeft: break; //default behaviour
                            case CKLayoutHorizontalAlignmentCenter:  offsetX = (self.frame.size.width - totalWidth) / 2; break;
                            case CKLayoutHorizontalAlignmentRight:   offsetX = (self.frame.size.width - totalWidth); break;
                        }
                    }
                    
                    box.frame = CGRectIntegral(CGRectMake(box.frame.origin.x + offsetX,box.frame.origin.y + offsetY,box.frame.size.width,box.frame.size.height));
                    [box performLayoutWithFrame:box.frame];
                }
            }
        }
    }
}

@end


//UILabel

@interface UILabel (Layout)
@end

//UIButton

@interface UIButton (Layout)
@end

//UITextView

@interface UITextView (Layout)
@end

//UITextField

@interface UITextField (Layout)
@end


//UILabel

@implementation UILabel (Layout)

- (CGSize)preferedSizeConstraintToSize:(CGSize)size{
    if(CGSizeEqualToSize(size, self.lastComputedSize))
        return self.lastPreferedSize;
    self.lastComputedSize = size;
    
    size.width -= self.padding.left + self.padding.right;
    size.height -= self.padding.top + self.padding.bottom;
    
    CGSize maxSize = CGSizeMake(size.width, (self.numberOfLines > 0) ? self.numberOfLines * self.font.lineHeight : MAXFLOAT);
    CGSize ret = [self.text sizeWithFont:self.font constrainedToSize:maxSize lineBreakMode:self.lineBreakMode];
    
    if([self.containerLayoutBox isKindOfClass:[CKVerticalBoxLayout class]])
        ret.width = size.width;
    
    ret = [CKLayoutBox preferedSizeConstraintToSize:ret forBox:self];
    
    self.lastPreferedSize = CGSizeMake(MIN(size.width,ret.width) + self.padding.left + self.padding.right,MIN(size.height,ret.height) + self.padding.top + self.padding.bottom);
    return self.lastPreferedSize;
}

- (void)UILabel_Layout_setText:(NSString*)text{
    [self UILabel_Layout_setText:text];
    [self invalidateLayout];
}

- (void)UILabel_Layout_setFont:(UIFont*)font{
    [self UILabel_Layout_setFont:font];
    [self invalidateLayout];
}

+ (void)load{
    CKSwizzleSelector([UILabel class], @selector(setText:), @selector(UILabel_Layout_setText:));
    CKSwizzleSelector([UILabel class], @selector(setFont:), @selector(UILabel_Layout_setFont:));
}

@end

//UITextField

@implementation UITextField (Layout)

- (CGSize)preferedSizeConstraintToSize:(CGSize)size{
    if(CGSizeEqualToSize(size, self.lastComputedSize))
        return self.lastPreferedSize;
    self.lastComputedSize = size;
    
    size.width -= self.padding.left + self.padding.right;
    size.height -= self.padding.top + self.padding.bottom;
    
    CGSize maxSize = CGSizeMake(size.width, MAXFLOAT);
    CGSize ret = [self.text sizeWithFont:self.font constrainedToSize:maxSize];
    
    if([self.containerLayoutBox isKindOfClass:[CKVerticalBoxLayout class]])
        ret.width = size.width;
    
    ret = [CKLayoutBox preferedSizeConstraintToSize:ret forBox:self];
    
    //Adds padding 8
    self.lastPreferedSize = CGSizeMake(MIN(size.width,ret.width) + self.padding.left + self.padding.right,MIN(size.height,ret.height) + self.padding.top + self.padding.bottom);
    return self.lastPreferedSize;
}

- (void)invalidateLayout{
    if([[self superview] isKindOfClass:[UIButton class]]){
        UIButton* bu = (UIButton*)[self superview];
        [bu invalidateLayout];
        return;
    }
        
    [super invalidateLayout];
}

- (void)UITextField_Layout_setText:(NSString*)text{
    [self UITextField_Layout_setText:text];
    [self invalidateLayout];
}

- (void)UITextField_Layout_setFont:(UIFont*)font{
    [self UITextField_Layout_setFont:font];
    [self invalidateLayout];
}

+ (void)load{
    CKSwizzleSelector([UITextField class], @selector(setText:), @selector(UITextField_Layout_setText:));
    CKSwizzleSelector([UITextField class], @selector(setFont:), @selector(UITextField_Layout_setFont:));
}

@end


//UITextView

@implementation UITextView (Layout)

- (CGSize)preferedSizeConstraintToSize:(CGSize)size{
    if(CGSizeEqualToSize(size, self.lastComputedSize))
        return self.lastPreferedSize;
    self.lastComputedSize = size;
    
    size.width -= self.padding.left + self.padding.right;
    size.height -= self.padding.top + self.padding.bottom;
    
    CGSize maxSize = CGSizeMake(size.width, MAXFLOAT);
    CGSize ret = [self.text sizeWithFont:self.font constrainedToSize:maxSize];
    
    if([self.containerLayoutBox isKindOfClass:[CKVerticalBoxLayout class]])
        ret.width = size.width;
    
    ret = CGSizeMake(MAX(size.width,ret.width) ,MAX(size.height,ret.height));
    ret = [CKLayoutBox preferedSizeConstraintToSize:ret forBox:self];
    
    //Adds padding 8
    self.lastPreferedSize = CGSizeMake(ret.width + self.padding.left + self.padding.right,ret.height + self.padding.top + self.padding.bottom);
    return self.lastPreferedSize;
}

- (void)UITextView_Layout_setText:(NSString*)text{
    [self UITextView_Layout_setText:text];
    [self invalidateLayout];
}

- (void)UITextView_Layout_setFont:(UIFont*)font{
    [self UITextView_Layout_setFont:font];
    [self invalidateLayout];
}

+ (void)load{
    CKSwizzleSelector([UITextView class], @selector(setText:), @selector(UITextView_Layout_setText:));
    CKSwizzleSelector([UITextView class], @selector(setFont:), @selector(UITextView_Layout_setFont:));
}

@end


//UILabel

@implementation UIButton (Layout)

- (CGSize)preferedSizeConstraintToSize:(CGSize)size{
    if(CGSizeEqualToSize(size, self.lastComputedSize))
        return self.lastPreferedSize;
    self.lastComputedSize = size;
    
    size.width -= self.padding.left + self.padding.right;
    size.height -= self.padding.top + self.padding.bottom;
    
    CGSize ret = [self sizeThatFits:size];
    ret = [CKLayoutBox preferedSizeConstraintToSize:ret forBox:self];
    
    self.lastPreferedSize = CGSizeMake(MIN(size.width,ret.width) + self.padding.left + self.padding.right,MIN(size.height,ret.height) + self.padding.top + self.padding.bottom);
    return self.lastPreferedSize;
}

@end








/**************************************************** UIView extension *************************************
 */


//UIView runtime properties.
static char UIViewMaximumSizeKey;
static char UIViewMinimumSizeKey;
static char UIViewMarginsKey;
static char UIViewPaddingKey;
static char UIViewLayoutBoxesKey;
static char UIViewContainerLayoutBoxKey;
static char UIViewLastComputedSizeKey;
static char UIViewLastPreferedSizeKey;
static char UIViewInvalidatedLayoutBlockKey;

@interface UIView (Layout_Private)
@end

@implementation UIView (Layout_Private)

- (void)setInvalidatedLayoutBlock:(CKLayoutBoxInvalidatedBlock)invalidatedLayoutBlock{
    objc_setAssociatedObject(self, 
                             &UIViewInvalidatedLayoutBlockKey,
                             [invalidatedLayoutBlock copy],
                             OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (CKLayoutBoxInvalidatedBlock)invalidatedLayoutBlock{
    return objc_getAssociatedObject(self, &UIViewInvalidatedLayoutBlockKey);
}

- (void)setFixedSize:(CGSize)size{
    self.maximumSize = size;
    self.minimumSize = size;
}

- (void)setLastComputedSize:(CGSize)s{
    objc_setAssociatedObject(self, 
                             &UIViewLastComputedSizeKey,
                             [NSValue valueWithCGSize:s],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGSize)lastComputedSize{
    id value = objc_getAssociatedObject(self, &UIViewLastComputedSizeKey);
    return value ? [value CGSizeValue] : CGSizeMake(0, 0);
}


- (void)setLastPreferedSize:(CGSize)s{
    objc_setAssociatedObject(self, 
                             &UIViewLastPreferedSizeKey,
                             [NSValue valueWithCGSize:s],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGSize)lastPreferedSize{
    id value = objc_getAssociatedObject(self, &UIViewLastPreferedSizeKey);
    return value ? [value CGSizeValue] : CGSizeMake(0, 0);
}



- (CGSize)fixedSize{
    if(CGSizeEqualToSize(self.maximumSize, self.minimumSize)){
        return self.minimumSize;
    }
    return CGSizeMake(MAXFLOAT, MAXFLOAT);
}

- (void)setMaximumSize:(CGSize)s{
    objc_setAssociatedObject(self, 
                             &UIViewMaximumSizeKey,
                             [NSValue valueWithCGSize:s],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGSize)maximumSize{
    id value = objc_getAssociatedObject(self, &UIViewMaximumSizeKey);
    return value ? [value CGSizeValue] : CGSizeMake(0, 0);
}

- (void)setMinimumSize:(CGSize)s{
    objc_setAssociatedObject(self, 
                             &UIViewMinimumSizeKey,
                             [NSValue valueWithCGSize:s],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGSize)minimumSize{
    id value = objc_getAssociatedObject(self, &UIViewMinimumSizeKey);
    return value ? [value CGSizeValue] : CGSizeMake(0, 0);
}

- (void)setMargins:(UIEdgeInsets)m{
    objc_setAssociatedObject(self, 
                             &UIViewMarginsKey,
                             [NSValue valueWithUIEdgeInsets:m],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)margins{
    id value = objc_getAssociatedObject(self, &UIViewMarginsKey);
    return value ? [value UIEdgeInsetsValue] : UIEdgeInsetsMake(0, 0, 0, 0);
}

- (void)setPadding:(UIEdgeInsets)m{
    objc_setAssociatedObject(self, 
                             &UIViewPaddingKey,
                             [NSValue valueWithUIEdgeInsets:m],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIEdgeInsets)padding{
    id value = objc_getAssociatedObject(self, &UIViewPaddingKey);
    return value ? [value UIEdgeInsetsValue] : UIEdgeInsetsMake(0, 0, 0, 0);
}

- (void)setLayoutBoxes:(NSArray*)m{
    if(self.layoutBoxes){
        [CKLayoutBox removeLayoutBoxes:self.layoutBoxes fromBox:self];
    }
    
    objc_setAssociatedObject(self, 
                             &UIViewLayoutBoxesKey,
                             m,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if(m){
        [CKLayoutBox addLayoutBoxes:m toBox:self];
    }
}

- (NSArray*)layoutBoxes{
    return objc_getAssociatedObject(self, &UIViewLayoutBoxesKey);
}

- (void)setContainerLayoutBox:(NSObject<CKLayoutBoxProtocol>*)c{
    objc_setAssociatedObject(self, 
                             &UIViewContainerLayoutBoxKey,
                             c,
                             OBJC_ASSOCIATION_ASSIGN);
}

- (NSObject<CKLayoutBoxProtocol>*)containerLayoutBox{
    return objc_getAssociatedObject(self, &UIViewContainerLayoutBoxKey);
}

- (UIView*)containerLayoutView{
    return self;
}

- (void)setMaximumWidth:(CGFloat)f  { self.maximumSize = CGSizeMake(f,self.maximumSize.height); }
- (void)setMaximumHeight:(CGFloat)f { self.maximumSize = CGSizeMake(self.maximumSize.width,f); }
- (void)setMinimumWidth:(CGFloat)f  { self.minimumSize = CGSizeMake(f,self.minimumSize.height); }
- (void)setMinimumHeight:(CGFloat)f { self.minimumSize = CGSizeMake(self.minimumSize.width,f); }
- (void)setFixedWidth:(CGFloat)f    { self.maximumWidth = f; self.minimumWidth = f; }
- (void)setFixedHeight:(CGFloat)f   { self.maximumHeight = f; self.minimumHeight = f; }
- (void)setMarginLeft:(CGFloat)f    { UIEdgeInsets insets = self.margins; insets.left = f; self.margins = insets; }
- (void)setMarginTop:(CGFloat)f     { UIEdgeInsets insets = self.margins; insets.top = f; self.margins = insets; }
- (void)setMarginBottom:(CGFloat)f  { UIEdgeInsets insets = self.margins; insets.bottom = f; self.margins = insets; }
- (void)setMarginRight:(CGFloat)f   { UIEdgeInsets insets = self.margins; insets.right = f; self.margins = insets; }
- (void)setPaddingLeft:(CGFloat)f   { UIEdgeInsets insets = self.padding; insets.left = f; self.padding = insets; }
- (void)setPaddingTop:(CGFloat)f    { UIEdgeInsets insets = self.padding; insets.top = f; self.padding = insets; }
- (void)setPaddingBottom:(CGFloat)f { UIEdgeInsets insets = self.padding; insets.bottom = f; self.padding = insets; }
- (void)setPaddingRight:(CGFloat)f  { UIEdgeInsets insets = self.padding; insets.right = f; self.padding = insets; }


- (CGFloat)maximumWidth  { return self.maximumSize.width; }
- (CGFloat)maximumHeight { return self.maximumSize.height; }
- (CGFloat)minimumWidth  { return self.minimumSize.width; }
- (CGFloat)minimumHeight { return self.minimumSize.height; }
- (CGFloat)fixedWidth    { return (self.maximumWidth == self.minimumWidth) ? self.maximumWidth : MAXFLOAT; }
- (CGFloat)fixedHeight   { return (self.maximumHeight == self.minimumHeight) ? self.maximumHeight : MAXFLOAT; }
- (CGFloat)marginLeft    { return self.margins.left; }
- (CGFloat)marginTop     { return self.margins.top; }
- (CGFloat)marginBottom  { return self.margins.bottom; }
- (CGFloat)marginRight   { return self.margins.right; }
- (CGFloat)paddingLeft   { return self.padding.left; }
- (CGFloat)paddingTop    { return self.padding.top; }
- (CGFloat)paddingBottom { return self.padding.bottom; }
- (CGFloat)paddingRight  { return self.padding.right; }

- (void)UIView_Layout_layoutSubviews{
    [self UIView_Layout_layoutSubviews];
    
    if(self.layoutBoxes && !self.containerLayoutBox){
        [self performLayoutWithFrame:self.bounds];
    }
}

- (id)UIView_Layout_init{
    self = [self UIView_Layout_init];
    [CKLayoutBox initializeBox:self];
    return self;
}

- (id)UIView_Layout_initWithFrame:(CGRect)frame{
    self = [self UIView_Layout_initWithFrame:frame];
    [CKLayoutBox initializeBox:self];
    return self;
}

- (void)UIView_Layout_setHidden:(BOOL)hidden{
    [self UIView_Layout_setHidden:hidden];
    [self invalidateLayout];
}

+ (void)load{
    CKSwizzleSelector([UIView class], @selector(layoutSubviews), @selector(UIView_Layout_layoutSubviews));
    CKSwizzleSelector([UIView class], @selector(init), @selector(UIView_Layout_init));
    CKSwizzleSelector([UIView class], @selector(initWithFrame:), @selector(UIView_Layout_initWithFrame:));
    CKSwizzleSelector([UIView class], @selector(setHidden:), @selector(UIView_Layout_setHidden:));
}

@end