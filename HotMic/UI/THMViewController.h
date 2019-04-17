//
//  ViewController.h
//  HotMic
//
//  Created by Chris Jones on 17/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "THMAudioDeviceList.h"
#import "THMMenuItem.h"
#import "THMSliderCell.h"
#import "THMSingleton.h"

@interface THMViewController : NSViewController
@property (weak, nonatomic) IBOutlet NSPopUpButton *inputSelector;
@property (weak, nonatomic) IBOutlet NSPopUpButton *outputSelector;
@property (weak, nonatomic) IBOutlet NSSlider *inputSlider;
@property (weak, nonatomic) IBOutlet NSSlider *outputSlider;
@property (weak, nonatomic) IBOutlet THMSliderCell *inputSliderCell;
@property (weak, nonatomic) IBOutlet THMSliderCell *outputSliderCell;
@property (weak, nonatomic) IBOutlet NSButton *enabledButton;

@property (nonatomic) THMAudioDeviceList *deviceList;
@property (nonatomic, setter=setInputDevice:) THMAudioDevice *inputDevice;
@property (nonatomic, setter=setOutputDevice:) THMAudioDevice *outputDevice;
@property (nonatomic) THMSingleton *singleton;
@property (nonatomic) NSTimer *dbTimer;

- (void)setUIEnabledState:(BOOL)enabled;
- (void)updateSelections:(NSNotification*)notification;
- (void)receiveUIState:(NSNotification*)notification;
- (IBAction)inputSelected:(id)sender;
- (IBAction)outputSelected:(id)sender;
- (IBAction)enabledSelected:(id)sender;
- (IBAction)inputSliderChanged:(id)sender;
- (IBAction)outputSliderChanged:(id)sender;

- (void)setInputDevice:(THMAudioDevice *)inputDevice;
- (void)setOutputDevice:(THMAudioDevice *)outputDevice;
@end

