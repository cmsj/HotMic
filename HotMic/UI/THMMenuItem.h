//
//  THMMenuItem.h
//  HotMic
//
//  Created by Chris Jones on 15/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface THMMenuItem : NSMenuItem
@property (strong, nonatomic) NSString *uid;

-(id)initWithTitle:(NSString *)title UID:(NSString *)UID;
@end

NS_ASSUME_NONNULL_END
