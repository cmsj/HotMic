//
//  THMSingleton.m
//  HotMic
//
//  Created by Chris Jones on 17/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import "THMSingleton.h"

@implementation THMSingleton

+ (THMSingleton *)sharedInstance {
    static THMSingleton *sharedInstance = nil;
    static dispatch_once_t onceToken; // onceToken = 0
    dispatch_once(&onceToken, ^{
        sharedInstance = [[THMSingleton alloc] init];
    });

    return sharedInstance;
}

- (id)init {
    self = [super init];
    if (self) {
        self.playThru = nil;
    }
    return self;
}

- (Float32)getLastAmplitude {
    if (self.playThru) {
        return self.playThru->lastAmplitude;
    }
    return 0.0;
}
@end
