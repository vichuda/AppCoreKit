//
//  NSObject+Invocation.h
//
//  Created by Fred Brunel.
//  Copyright 2011 WhereCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/Message.h>

/**
 */
@interface NSObject (CKNSObjectInvocation)

///-----------------------------------
/// @name Sending Messages
///-----------------------------------

/** 
 */
- (id)performSelector:(SEL)selector withObjects:(NSArray*)objects;

/** 
 */
- (void)performSelector:(SEL)selector withObject:(id)arg withObject:(id)arg2 afterDelay:(NSTimeInterval)delay;

/** 
 */
- (void)performSelectorOnMainThread:(SEL)selector withObject:(id)arg withObject:(id)arg2 waitUntilDone:(BOOL)wait;

/** 
 */
- (void)performSelectorOnMainThread:(SEL)selector withObject:(id)arg withObject:(id)arg2 withObject:(id)arg3 waitUntilDone:(BOOL)wait;


/** 
 */
- (id)performSelector:(SEL)selector onThread:(NSThread *)thread withObjects:(NSArray *)args waitUntilDone:(BOOL)wait;

/** 
 */
- (void)performBlock:(void (^)())block afterDelay:(NSTimeInterval)delay;

/**
 */
- (void)performBlockOnMainThread:(void (^)())block;

/** 
 */
- (void)cancelPeformBlock;

@end