//
//  OKGameCenterUtilities.m
//  OpenKit
//
//  Created by Suneet Shah on 6/12/13.
//  Copyright (c) 2013 OpenKit. All rights reserved.
//

#import "OKGameCenterUtilities.h"
#import "OKUserUtilities.h"
#import "OKMacros.h"
#import "OKManager.h"
#import "OKUser.h"

@implementation OKGameCenterUtilities

// Check to see if the device supports GameCenter
// This method is slightly redundant because OpenKit only supports iOS 5+
+(BOOL)isGameCenterAvailable
{
    // Check for presence of GKLocalPlayer API.
    Class gcClass = (NSClassFromString(@"GKLocalPlayer"));
    
    // The device must be running running iOS 4.1 or later.
    NSString *reqSysVer = @"4.1";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    BOOL osVersionSupported = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);
    
    return (gcClass && osVersionSupported);
}

// This method only works with iOS 6+
+(void)authorizeUserWithGameCenterAndallowUI:(BOOL)allowUI withPresentingViewController:(UIViewController*)presenter
{
    
    if([self shouldUseLegacyGameCenterAuth]) {
        [self authorizeUserWithGameCenterLegacy];
        return;
    }
    
    
    [GKLocalPlayer localPlayer].authenticateHandler = ^(UIViewController *viewController, NSError *error) {
        
        if(viewController != nil) {
            // show the auth dialog
            OKLog(@"Need to show GameCenter dialog");
            
            if(presenter) {
                [presenter presentModalViewController:viewController animated:YES];
            }
                
        } else if ([GKLocalPlayer localPlayer].isAuthenticated) {
            // local player is authenticated
            OKLog(@"Authenticated with GameCenter");
            [self loginToOpenKitWithGameCenterUser:[GKLocalPlayer localPlayer]];
        } else {
            // local player is not authenticated
            OKLog(@"Did not auth with GameCenter, error: %@", error);
        }
    };
}

// Authenticate with GameCenter on iOS5
+(void)authorizeUserWithGameCenterLegacy {
    
    // This gamecenter method is deprecated in iOS6 but is required for iOS 5 support
    
    GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
    [localPlayer authenticateWithCompletionHandler:^(NSError *error) {
        if (localPlayer.isAuthenticated)
        {
            // local player is authenticated
            OKLog(@"Authenticated with GameCenter iOS5 style");
            [self loginToOpenKitWithGameCenterUser:[GKLocalPlayer localPlayer]];
        }
        else
        {
            // local player is not authenticated
            OKLog(@"Did not auth with GameCenter (iOS5 style), error: %@", error);
        }
    }];
}

// Check to see if we should use iOS5 version of GameCenter authentication or not
+(BOOL)shouldUseLegacyGameCenterAuth
{
    // IF GKLocalPlayer responds to setAuthenticationHandler, then this is iOS 6+ so return NO, otherwise
    // use legacy version (return YES)
    
    if([[GKLocalPlayer localPlayer] respondsToSelector:@selector(setAuthenticateHandler:)])
        return NO;
    else
        return YES;
}



+(void)authenticateLocalPlayer
{
    OKLog(@"Authenticating local GC player and logging into OpenKit");
    
    if([self shouldUseLegacyGameCenterAuth])
        [OKGameCenterUtilities authorizeUserWithGameCenterLegacy];
    else
        [OKGameCenterUtilities authorizeUserWithGameCenterAndallowUI:NO withPresentingViewController:nil];
}

/** Manages the logic for logging into OpenKit with GameCenter **/
+(void)loginToOpenKitWithGameCenterUser:(GKPlayer*)player
{
    OKLog(@"Logging into OpenKit with GameCenter");
     // If there is already a cached OKUser, then update the user for GameCenter
    if([OKUser currentUser] != nil) {
        [self updateOKUserForGamecenterUser:player withOKUser:[OKUser currentUser]];
    }
    else {
        [self getOKUserWithGamecenterUser:[GKLocalPlayer localPlayer]];
    }
}

/** Given an OKUser and a GKPlayer, decides whether the cached OKUser should be updated to reflect the GameCenter ID, or should be logged out and a new OKUser should be created **/
+(void)updateOKUserForGamecenterUser:(GKPlayer*)player withOKUser:(OKUser*)user
{
    if([user gameCenterID] == nil || [[user gameCenterID] isKindOfClass:[NSNull class]]) {
        //Current user doesn't have a game center ID, but it should have some other type of ID
        // TODO, add GameCenter ID to current user, e.g. UPDATE the user
        OKLog(@"TODO update existing user with GameCenter ID");
    }
    else if ([user gameCenterID] && ![[user gameCenterID] isEqualToString:[player playerID]]) {
        OKLog(@"New GameCenter user found from previous cached gamecenter user");
        // If the cached/current OKUser's GC ID != localPlayer GC ID, then logout and re-login
        [[OKManager sharedManager] logoutCurrentUser];
        [self getOKUserWithGamecenterUser:player];
    }
}

/** Given a GKPlayer, sends a POST to OKUSer with that gamecenter ID--> "create or get"
    If the login is successful, OKUser is cached as the currentUser
 **/
+(void)getOKUserWithGamecenterUser:(GKPlayer*)player
{
    [OKUserUtilities createOKUserWithUserIDType:GameCenterIDType withUserID:[player playerID] withUserNick:[player alias] withCompletionHandler:^(OKUser *user, NSError *error) {
        
        if(!error) {
            //Save the current user
            [user setGameCenterID:[player playerID]];
            [[OKManager sharedManager] saveCurrentUser:user];
            OKLog(@"Logged into OpenKit with GameCenter ID: %@, display name: %@",[player playerID], [user userNick]);
        } else {
            OKLog(@"Failed to login to OpenKit with gamecenter ID");
        }
    }];
}

+(void)loadPlayerPhotoForGameCenterID:(NSString*)gameCenterID withPhotoSize:(GKPhotoSize)photoSize withCompletionHandler:(void(^)(UIImage *photo, NSError *error))completionhandler
{
    [GKPlayer loadPlayersForIdentifiers:[NSArray arrayWithObject:gameCenterID] withCompletionHandler:^(NSArray *players, NSError *error) {
        if (error != nil)
        {
            // Couldn't load the player info, so can't load profile photo
            completionhandler(nil,error);
        }
        else if (players != nil)
        {
            GKPlayer *player = [players objectAtIndex:0];
            [player loadPhotoForSize:photoSize withCompletionHandler:^(UIImage *photo, NSError *error) {
                completionhandler(photo, error);
            }];
        }
        else {
            completionhandler(nil,error);
        }
    }];
}

+(BOOL)isPlayerAuthenticatedWithGameCenter {
    return [GKLocalPlayer localPlayer].isAuthenticated;
}

@end
