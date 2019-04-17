//
//  THMAudioDeviceSource.h
//  HotMic
//
//  Created by Chris Jones on 29/03/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface THMAudioDeviceSource : NSObject {
    NSString *nameCache;
}
@property UInt32 ID;
@property UInt32 deviceID;
@property BOOL isInput;
@property (readonly, getter=getName) NSString *name;

- (id)initWithSourceID:(UInt32)ID andDeviceID:(AudioDeviceID)deviceID input:(BOOL)input;
- (BOOL)setDefault;

// These are private methods for getters
- (NSString *)getName;
@end

NS_ASSUME_NONNULL_END
