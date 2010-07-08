//
//  CKToggleSwitchCellController.h
//  CloudKit
//
//  Created by Olivier Collet on 10-06-10.
//  Copyright 2010 WhereCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CKStandardCellController.h"


@interface CKToggleSwitchCellController : CKStandardCellController {
	BOOL _enabled;
}

@property (nonatomic, assign, getter=isEnabled, setter=enable:) BOOL enabled;

- (id)initWithTitle:(NSString *)title value:(BOOL)value;

@end
