//
//  CKBindings.m
//  CloudKit
//
//  Created by Sebastien Morel on 11-03-11.
//  Copyright 2011 WhereCloud Inc. All rights reserved.
//

#import "CKNSObject+Bindings.h"
#import "CKBindingsManager.h"
#import "CKUIControlBlockBinder.h"
#import "CKDataBinder.h"
#import "CKNotificationBlockBinder.h"
#import "CKDataBlockBinder.h"


static id CKBindingsCurrentContext = nil;
static id CKBindingsPreviousContext = nil;
static NSString* CKBindingsNoContext = @"CKBindingsNoContext";


@implementation NSObject (CKBindings)

+ (NSString *)allBindingsDescription{
	return [[CKBindingsManager defaultManager]description];
}

+ (void)beginBindingsContext:(id)context{
	[NSObject beginBindingsContext:context policy:CKBindingsContextPolicyAdd];
}

+ (void)beginBindingsContext:(id)context policy:(CKBindingsContextPolicy)policy{
	CKBindingsPreviousContext = CKBindingsCurrentContext;
	CKBindingsCurrentContext = context;
	
	if(policy == CKBindingsContextPolicyRemovePreviousBindings){
		[[CKBindingsManager defaultManager] unbindAllBindingsWithContext:context];
	}
}

+ (void)endBindingsContext{
	CKBindingsCurrentContext = CKBindingsPreviousContext;
}

+ (void)removeAllBindingsForContext:(id)context{
	[[CKBindingsManager defaultManager]unbindAllBindingsWithContext:context];
}

- (void)removeAllBindings{
	[[CKBindingsManager defaultManager]unbindAllBindingsWithContext:self];
}

- (void)bind:(NSString *)keyPath toObject:(id)object withKeyPath:(NSString *)keyPath2{
	CKDataBinder* binder = (CKDataBinder*)[[CKBindingsManager defaultManager]dequeueReusableBindingWithClass:[CKDataBinder class]];
	[binder setInstance1:self];
	binder.keyPath1 = keyPath;
	[binder setInstance2:object];
	binder.keyPath2 = keyPath2;
	[[CKBindingsManager defaultManager]bind:binder withContext:CKBindingsCurrentContext ? CKBindingsCurrentContext : CKBindingsNoContext];
	[binder release];
}

- (void)bind:(NSString *)keyPath withBlock:(void (^)(id value))block{
	CKDataBlockBinder* binder = (CKDataBlockBinder*)[[CKBindingsManager defaultManager]dequeueReusableBindingWithClass:[CKDataBlockBinder class]];
	[binder setInstance:self];
	binder.keyPath = keyPath;
	binder.block = block;
	[[CKBindingsManager defaultManager]bind:binder withContext:CKBindingsCurrentContext ? CKBindingsCurrentContext : CKBindingsNoContext];
	[binder release];
}

- (void)bind:(NSString *)keyPath target:(id)target action:(SEL)selector{
	CKDataBlockBinder* binder = (CKDataBlockBinder*)[[CKBindingsManager defaultManager]dequeueReusableBindingWithClass:[CKDataBlockBinder class]];
	[binder setInstance:self];
	binder.keyPath = keyPath;
	[binder setTarget:target];
	binder.selector = selector;
	[[CKBindingsManager defaultManager]bind:binder withContext:CKBindingsCurrentContext ? CKBindingsCurrentContext : CKBindingsNoContext];
	[binder release];
}

- (void)bindNotificationName:(NSString *)notification withBlock:(void (^)(NSNotification *notification))block{
	CKNotificationBlockBinder* binder = (CKNotificationBlockBinder*)[[CKBindingsManager defaultManager]dequeueReusableBindingWithClass:[CKNotificationBlockBinder class]];
	[binder setInstance:self];
	binder.block = block;
	binder.notificationName = notification;
	[[CKBindingsManager defaultManager]bind:binder withContext:CKBindingsCurrentContext ? CKBindingsCurrentContext : CKBindingsNoContext];
	[binder release];
}

- (void)bindNotificationName:(NSString *)notification target:(id)target action:(SEL)selector{
	CKNotificationBlockBinder* binder = (CKNotificationBlockBinder*)[[CKBindingsManager defaultManager]dequeueReusableBindingWithClass:[CKNotificationBlockBinder class]];
	[binder setInstance:self];
	[binder setTarget:target];
	binder.selector = selector;
	binder.notificationName = notification;
	[[CKBindingsManager defaultManager]bind:binder withContext:CKBindingsCurrentContext ? CKBindingsCurrentContext : CKBindingsNoContext];
	[binder release];
}

@end

//

@implementation UIControl (CKBindings)

- (void)bindEvent:(UIControlEvents)controlEvents withBlock:(void (^)())block{
	CKUIControlBlockBinder* binder = (CKUIControlBlockBinder*)[[CKBindingsManager defaultManager]dequeueReusableBindingWithClass:[CKUIControlBlockBinder class]];
	binder.controlEvents = controlEvents;
	binder.block = block;
	[binder setControl:self];
	[[CKBindingsManager defaultManager]bind:binder withContext:CKBindingsCurrentContext ? CKBindingsCurrentContext : CKBindingsNoContext];
	[binder release];
}

- (void)bindEvent:(UIControlEvents)controlEvents target:(id)target action:(SEL)selector{
	CKUIControlBlockBinder* binder = (CKUIControlBlockBinder*)[[CKBindingsManager defaultManager]dequeueReusableBindingWithClass:[CKUIControlBlockBinder class]];
	binder.controlEvents = controlEvents;
	[binder setControl:self];
	[binder setTarget:target];
	binder.selector = selector;
	[[CKBindingsManager defaultManager]bind:binder withContext:CKBindingsCurrentContext ? CKBindingsCurrentContext : CKBindingsNoContext];
	[binder release];
}

@end

//

@implementation NSNotificationCenter (CKBindings)

- (void)bindNotificationName:(NSString *)notification object:(id)notificationSender withBlock:(void (^)(NSNotification *notification))block{
	CKNotificationBlockBinder* binder = (CKNotificationBlockBinder*)[[CKBindingsManager defaultManager]dequeueReusableBindingWithClass:[CKNotificationBlockBinder class]];
	[binder setInstance:notificationSender];
	binder.notificationName = notification;
	binder.block = block;
	[[CKBindingsManager defaultManager]bind:binder withContext:CKBindingsCurrentContext ? CKBindingsCurrentContext : CKBindingsNoContext];
	[binder release];
}

- (void)bindNotificationName:(NSString *)notification withBlock:(void (^)(NSNotification *notification))block{
	CKNotificationBlockBinder* binder = (CKNotificationBlockBinder*)[[CKBindingsManager defaultManager]dequeueReusableBindingWithClass:[CKNotificationBlockBinder class]];
	binder.notificationName = notification;
	binder.block = block;
	[[CKBindingsManager defaultManager]bind:binder withContext:CKBindingsCurrentContext ? CKBindingsCurrentContext : CKBindingsNoContext];
	[binder release];
}

- (void)bindNotificationName:(NSString *)notification object:(id)notificationSender target:(id)target action:(SEL)selector{
	CKNotificationBlockBinder* binder = (CKNotificationBlockBinder*)[[CKBindingsManager defaultManager]dequeueReusableBindingWithClass:[CKNotificationBlockBinder class]];
	[binder setInstance:notificationSender];
	[binder setTarget:target];
	binder.notificationName = notification;
	binder.selector = selector;
	[[CKBindingsManager defaultManager]bind:binder withContext:CKBindingsCurrentContext ? CKBindingsCurrentContext : CKBindingsNoContext];
	[binder release];
}

- (void)bindNotificationName:(NSString *)notification target:(id)target action:(SEL)selector{
	CKNotificationBlockBinder* binder = (CKNotificationBlockBinder*)[[CKBindingsManager defaultManager]dequeueReusableBindingWithClass:[CKNotificationBlockBinder class]];
	[binder setTarget:target];
	binder.notificationName = notification;
	binder.selector = selector;
	[[CKBindingsManager defaultManager]bind:binder withContext:CKBindingsCurrentContext ? CKBindingsCurrentContext : CKBindingsNoContext];
	[binder release];
}

@end


/*id subView = (viewTag >= 0) ? [self.view viewWithTag:viewTag] : self.view;
 id controlId = (keyPath == nil || [keyPath isEqualToString:@""]) ? subView : [subView valueForKeyPath:keyPath];
 if(!controlId){
 NSAssert(NO,@"Invalid control object in CKUIControlActionBlockBinder");
 }*/
