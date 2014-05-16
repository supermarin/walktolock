//
//  SKWAppDelegate.m
//  WalkToLock
//
//  Created by Marin Usalj on 5/16/14.
//  Copyright (c) 2014 Skywalkers. All rights reserved.
//

#import "SKWAppDelegate.h"
#import "HGBeaconScanner.h"
#import "HGBeacon.h"

#define HGBeaconTimeToLiveInterval 15

@interface SKWAppDelegate (){}
@property (strong, nonatomic) NSMutableArray *beacons;
@property (strong, nonatomic) RACSignal *housekeepingSignal;
@property (nonatomic) BOOL alreadyLocked;
@end

@implementation SKWAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    __weak typeof(self) weakSelf = self;
    self.beacons = @[].mutableCopy;

    // Subscribe to bluetooth state change signals from the beacon scanner
    [[[[HGBeaconScanner sharedBeaconScanner] bluetoothStateSignal] deliverOn:[RACScheduler mainThreadScheduler]] subscribeNext:^(NSString *const bluetoothState) {
        NSLog(@"bluetooth state changed: %@", bluetoothState);
    }];

    // Subscribe to beacons detected by the manager, modify beacon list that is bound to the table view array controller
    [[[[HGBeaconScanner sharedBeaconScanner] beaconSignal] deliverOn:[RACScheduler mainThreadScheduler]] subscribeNext:^(HGBeacon *beacon) {
        NSUInteger existingBeaconIndex = [weakSelf.beacons indexOfObjectPassingTest:^BOOL(HGBeacon *otherBeacon, NSUInteger idx, BOOL *stop) {
            return [beacon isEqualToBeacon:otherBeacon];
        }];
        if (existingBeaconIndex != NSNotFound) {
            HGBeacon *existingBeacon = weakSelf.beacons[existingBeaconIndex];

            existingBeacon.measuredPower = beacon.measuredPower;
            existingBeacon.RSSI = beacon.RSSI;
            existingBeacon.lastUpdated = beacon.lastUpdated;
            NSLog(@"existing beacon: %@", beacon.proximityUUID.UUIDString);
            NSLog(@"powa: %@", existingBeacon.RSSI);

            if ([existingBeacon.proximityUUID.UUIDString isEqual:@"B0702880-A295-A8AB-F734-031A98A512DE"]) {
                NSLog(@"DANIEL!");
                if (existingBeacon.RSSI.integerValue < -70 && !weakSelf.alreadyLocked) {
                    NSLog(@"LOCKING DANIEL");
                    [weakSelf lockTheComputer];
                }
            }

        } else {
            [weakSelf.beacons addObject:beacon];
            NSLog(@"new beacon: %@", beacon);
        }
    }];


    // Setup a interval signal that will purge expired beacons (determined by a last update longer than HGBeaconTimeToLiveInterval) from the displayed list
    self.housekeepingSignal = [RACSignal interval:1 onScheduler:[RACScheduler mainThreadScheduler]];
    [self.housekeepingSignal subscribeNext:^(NSDate *now) {

        if ([[HGBeaconScanner sharedBeaconScanner] scanning]) {
            NSArray *beaconsCopy = [NSArray arrayWithArray:self.beacons];
            for (HGBeacon *candidateBeacon in beaconsCopy) {
                NSTimeInterval age = [now timeIntervalSinceDate:candidateBeacon.lastUpdated];
                if (age > HGBeaconTimeToLiveInterval) {
                    NSUInteger index = 0;
                    for (HGBeacon *beacon in self.beacons) {
                        if ([beacon isEqualToBeacon:candidateBeacon]) {
                            [weakSelf.beacons removeObjectAtIndex:index];
                            break;
                        }
                        index++;
                    }
                }
            }
        }
    }];

    [[HGBeaconScanner sharedBeaconScanner] startScanning];
}

- (void)lockTheComputer {
    self.alreadyLocked = YES;
    NSBundle *bundle = [NSBundle bundleWithPath:@"/Applications/Utilities/Keychain Access.app/Contents/Resources/Keychain.menu"];
    Class principalClass = [bundle principalClass];

    id instance = [[principalClass alloc] init];
    [instance performSelector:@selector(_lockScreenMenuHit:) withObject:NULL];
}

@end
