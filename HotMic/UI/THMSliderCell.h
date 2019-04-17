//
//  THMSliderCell.h
//  HotMic
//
//  Created by Chris Jones on 17/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "THMSingleton.h"

NS_ASSUME_NONNULL_BEGIN

@interface THMSliderCell : NSSliderCell
@property (nonatomic) Float32 decibels;
@end

NS_ASSUME_NONNULL_END
