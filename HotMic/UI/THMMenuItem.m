//
//  THMMenuItem.m
//  HotMic
//
//  Created by Chris Jones on 15/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import "THMMenuItem.h"

@implementation THMMenuItem

-(id)initWithTitle:(NSString *)title UID:(NSString *)UID {
    self = [super self];
    if (self) {
        self.title = title;
        self.uid = UID;
    }
    return self;
}

@end
