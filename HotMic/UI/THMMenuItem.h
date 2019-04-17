//
//  THMMenuItem.h
//  HotMic
//
//  Created by Chris Jones on 15/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface THMMenuItem : NSMenuItem
@property (strong, nonatomic) NSString *uuid;

-(id)initWithTitle:(NSString *)title UUID:(NSString *)UUID;
@end

NS_ASSUME_NONNULL_END
