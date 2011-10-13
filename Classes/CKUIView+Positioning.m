//
//  UIView+CKPositioning.m
//  CloudKit
//
//  Created by Sebastien Morel on 11-10-13.
//  Copyright (c) 2011 Wherecloud. All rights reserved.
//

#import "CKUIView+Positioning.h"


@implementation UIView (CKPositioning)
@dynamic x,y,width,height;

- (CGFloat)x{
    return self.frame.origin.x;
}

- (void)setX:(CGFloat)x{
    CGRect theFrame = self.frame;
    theFrame.origin.x = x;
    self.frame = theFrame;
}

- (CGFloat)y{
    return self.frame.origin.y;
}

- (void)setY:(CGFloat)y{
    CGRect theFrame = self.frame;
    theFrame.origin.y = y;
    self.frame = theFrame;
}

- (CGFloat)width{
    return self.frame.size.width;
}

- (void)setWidth:(CGFloat)width{
    CGRect theFrame = self.frame;
    theFrame.size.width = width;
    self.frame = theFrame;
}

- (CGFloat)height{
    return self.frame.size.height;
}

- (void)setHeight:(CGFloat)height{
    CGRect theFrame = self.frame;
    theFrame.size.height = height;
    self.frame = theFrame;
}

@end
