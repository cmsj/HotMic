//
//  THMSliderCell.m
//  HotMic
//
//  Created by Chris Jones on 17/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import "THMSliderCell.h"

@implementation THMSliderCell

- (void)drawBarInside:(NSRect)rect flipped:(BOOL)flipped {
    // FIXME: Figure out how to get THMPlayThru's lastDecibels ivar here
    [super drawBarInside:rect flipped:flipped];
    THMSingleton *singleton = [THMSingleton sharedInstance];

    [[NSColor controlAccentColor] set];
    NSRect dbRect = NSMakeRect(rect.origin.x + 2, rect.origin.y + 2, (rect.size.width * (singleton.lastDecibels / 100)) - 4, rect.size.height - 4);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:dbRect xRadius:0 yRadius:0];
    [path fill];
}

@end
