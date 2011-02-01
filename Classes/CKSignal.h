//
//  CKSignal.h
//  CloudKitApp
//
//  Created by Sebastien Morel on 11-01-19.
//  Copyright 2011 WhereCloud Inc. All rights reserved.
//

@interface CKSlot : NSObject{
	id instance;
	SEL selector;
	int priority;
}

@property (nonatomic, retain, readwrite) id  instance;
@property (nonatomic, assign,readwrite) SEL selector;
@property (nonatomic, assign,readwrite) int priority;

+(CKSlot*)slotWith : (id)object sel:(SEL)sel;
+(CKSlot*)slotWith : (id)object sel:(SEL)sel p:(int)p;

- (NSMethodSignature*) getSignature;
- (BOOL)valid;

@end

@interface CKSignal : NSObject {
	NSMethodSignature* methodSignature;
	NSMutableArray* slotArray;
}

+(CKSignal*)signalWithSignature:(NSMethodSignature*)signature;
+(CKSignal*)signalWithTypes:(char*)argType0,...;


-(BOOL)addSlotArrayObject:(id)object;
-(BOOL)removeSlot:(id)slot;
-(void)send:(NSArray*)arguments;

@property (nonatomic, retain, readwrite) NSMethodSignature*  methodSignature;
@property (nonatomic, retain, readwrite) NSArray*  slotArray;

//[[NSString stringWithFormat:@"%s%s%s%s", @encode(id), @encode(id), @encode(SEL), @encode(int)] UTF8String]

@end
