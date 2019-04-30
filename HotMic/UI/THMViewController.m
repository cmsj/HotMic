//
//  ViewController.m
//  HotMic
//
//  Created by Chris Jones on 17/04/2019.
//  Copyright © 2019 Chris Jones. All rights reserved.
//

#import "THMViewController.h"

@implementation THMViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self updateSelections:[NSNotification notificationWithName:@"THMNULL" object:nil]];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    [center addObserver:self selector:@selector(updateSelections:) name:@"THMControllerAudioDevicesChanged" object:nil];
    [center addObserver:self selector:@selector(receiveUIState:) name:@"THMControllerPushUIState" object:nil];

    [center postNotificationName:@"THMViewDidLoad" object:nil];

    self.singleton = [THMSingleton sharedInstance];
}

- (void)viewDidAppear {
    __weak THMViewController *weakself = self;
    self.dbTimer = [NSTimer scheduledTimerWithTimeInterval:1/30
                                                   repeats:YES
                                                     block:^(NSTimer * _Nonnull timer)
    {
        Float32 newAmplitude = self.singleton.lastAmplitude;
        //NSLog(@"%0.2f -> %0.2f", weakself.inputSliderCell.amplitude, newAmplitude);
        if (newAmplitude != weakself.inputSliderCell.amplitude) {
            // If the amplitude has fallen, add a decay so the UI looks like these things seem to
            if (newAmplitude < weakself.inputSliderCell.amplitude - 0.1) {
                weakself.inputSliderCell.amplitude -= 0.01;
            } else {
                weakself.inputSliderCell.amplitude = newAmplitude;
            }
            weakself.inputSlider.needsDisplay = YES;
        }
    }];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:@"THMUIDidAppear" object:nil];
}

- (void)viewDidDisappear {
    [self.dbTimer invalidate];
    self.dbTimer = nil;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:@"THMUIDidDisappear" object:nil];
}

#pragma mark - NSNotification callbacks

- (void)setUIEnabledState:(BOOL)enabled {
    for (id widget in @[self.enabledButton,
                        self.inputSelector,
                        self.outputSelector,
                        self.inputSlider,
                        self.outputSlider])
    {
        ((NSControl *)widget).enabled = enabled;
    }
}

- (void)updateSelections:(NSNotification*)notification {
    NSLog(@"UI updating device selection");
    self.deviceList = [[THMAudioDeviceList alloc] init];
    THMAudioDevice *defaultInput = [THMAudioDeviceList getDefaultDevice:YES];
    THMAudioDevice *defaultOutput = [THMAudioDeviceList getDefaultDevice:NO];

    // Create the menu for Input Devices
    [self.inputSelector removeAllItems];

    // Create an NSMenu to hold the input devices
    NSMenu *inputMenu = [[NSMenu alloc] initWithTitle:@"Inputs"];

    // Create the "System Default" menu item and add it
    NSString *title = [NSString stringWithFormat:@"%@ (%@)", @"System Default", defaultInput.name];
    THMMenuItem *defaultItem = [[THMMenuItem alloc] initWithTitle:title
                                                              UID:@"__THM__DEFAULT_DEVICE__"];
    [inputMenu addItem:defaultItem];

    // Add a separator
    [inputMenu addItem:[THMMenuItem separatorItem]];

    // Add the devices
    for (THMAudioDevice *device in self.deviceList.inputDevices) {
        THMMenuItem *menuItem = [[THMMenuItem alloc] initWithTitle:device.name UID:device.UID];
        [inputMenu addItem:menuItem];
    }

    // Set the Input Devices menu
    self.inputSelector.menu = inputMenu;

    // Create the menu for Output Devices
    [self.outputSelector removeAllItems];

    // Create an NSMenu to hold the output devices
    NSMenu *outputMenu = [[NSMenu alloc] initWithTitle:@"Outputs"];

    // Create the "System Default" menu item and add it
    defaultItem = [[THMMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ (%@)", @"System Default", defaultOutput.name]
                                                UID:@"__THM__DEFAULT_DEVICE__"];
    [outputMenu addItem:defaultItem];

    // Add a separator
    [outputMenu addItem:[THMMenuItem separatorItem]];

    // Add the devices
    for (THMAudioDevice *device in self.deviceList.outputDevices) {
        THMMenuItem *menuItem = [[THMMenuItem alloc] initWithTitle:device.name UID:device.UID];
        [outputMenu addItem:menuItem];
    }

    // Set the Output Devices menu
    self.outputSelector.menu = outputMenu;
}

- (void)receiveUIState:(NSNotification*)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSLog(@"receiveUIState: %@", userInfo);

    [self setUIEnabledState:((NSNumber*)userInfo[@"startupDone"]).boolValue];
    self.enabledButton.state = ((NSNumber*)userInfo[@"isEnabled"]).boolValue ? NSControlStateValueOn : NSControlStateValueOff;

    // Set the input device
    NSString *inputUID = userInfo[@"inputDeviceUID"];
    for (NSMenuItem *item in self.inputSelector.itemArray) {
        if ([((THMMenuItem *)item).uid isEqualToString:inputUID]) {
            [self.inputSelector selectItem:item];
            self.inputDevice = [self.deviceList audioDeviceForUID:inputUID input:YES];
            break;
        }
    }

    // Set the output device
    NSString *outputUID = userInfo[@"outputDeviceUID"];
    for (NSMenuItem *item in self.outputSelector.itemArray) {
        if ([((THMMenuItem *)item).uid isEqualToString:outputUID]) {
            [self.outputSelector selectItem:item];
            self.outputDevice = [self.deviceList audioDeviceForUID:outputUID input:NO];
            break;
        }
    }

    self.inputSlider.floatValue = ((NSNumber *)userInfo[@"inputVolume"]).floatValue;

    self.outputSlider.floatValue = ((NSNumber *)userInfo[@"outputVolume"]).floatValue;
}

#pragma mark - UI action callbacks

- (IBAction)inputSelected:(id)sender {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    THMMenuItem *item = (THMMenuItem *)((NSPopUpButton *)sender).selectedItem;

    NSLog(@"Sending input selection event for: %@ (%@)", item.title, item.uid);
    NSNotification *notification = [NSNotification notificationWithName:@"THMViewInputDeviceSelected"
                                                                 object:nil
                                                               userInfo:@{@"uuid":item.uid}];
    [center postNotification:notification];
    self.inputDevice = [self.deviceList audioDeviceForUID:item.uid input:YES];
}

- (IBAction)outputSelected:(id)sender {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    THMMenuItem *item = (THMMenuItem *)((NSPopUpButton *)sender).selectedItem;

    NSLog(@"Sending output selection event for: %@ (%@)", item.title, item.uid);
    NSNotification *notification = [NSNotification notificationWithName:@"THMViewOutputDeviceSelected" object:nil userInfo:@{@"uuid":item.uid}];
    [center postNotification:notification];
    self.outputDevice = [self.deviceList audioDeviceForUID:item.uid input:NO];
}

- (IBAction)enabledSelected:(id)sender {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSButton *button = (NSButton *)sender;
    NSNumber *state = [NSNumber numberWithBool:(button.state == NSControlStateValueOn) ? YES : NO];

    //NSLog(@"Sending enabled selection event: %@", state.boolValue ? @"SELECTED" : @"NOT SELECTED");
    NSNotification *notification = [NSNotification notificationWithName:@"THMViewEnabledSelected"
                                                                 object:nil
                                                               userInfo:@{@"state":state}];
    [center postNotification:notification];
}

- (IBAction)inputSliderChanged:(id)sender {
    self.inputDevice.volume = self.inputSlider.floatValue;
}

- (IBAction)outputSliderChanged:(id)sender {
    self.outputDevice.volume = self.outputSlider.floatValue;
}

#pragma mark - Private setters

- (void)setInputDevice:(THMAudioDevice *)inputDevice {
    if (_inputDevice) {
        [_inputDevice stopVolumeWatcher];
    }
    _inputDevice = inputDevice;
    [_inputDevice startVolumeWatcher:self.inputSlider];
}

- (void)setOutputDevice:(THMAudioDevice *)outputDevice {
    if (_outputDevice) {
        [_outputDevice stopVolumeWatcher];
    }
    _outputDevice = outputDevice;
    [_outputDevice startVolumeWatcher:self.outputSlider];
}

@end
