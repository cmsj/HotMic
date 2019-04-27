//
//  THMSingleton.h
//  HotMic
//
//  Created by Chris Jones on 17/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "THMBackEndBase.h"

NS_ASSUME_NONNULL_BEGIN

@interface THMSingleton : NSObject

@property (nonatomic) THMBackEndBase * _Nullable playThru;
@property (nonatomic, getter=getLastDecibels) Float32 lastDecibels;

+ (THMSingleton *)sharedInstance;

@end

NS_ASSUME_NONNULL_END
