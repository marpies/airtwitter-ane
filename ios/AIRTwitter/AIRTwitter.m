/**
 * Copyright 2015 Marcel Piestansky (http://marpies.com)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "AIR.h"
#import "AIRTwitter.h"
#import "AIRTwitterEvent.h"
#import "AIRTwitterUser.h"

static STTwitterAPI* mTwitter = nil;

static NSString* mURLScheme = nil;
static NSString* mConsumerKey = nil;
static NSString* mConsumerSecret = nil;

static AIRTwitterUser* mLoggedInUser = nil;

@interface AIRTwitter ()
@end

@implementation AIRTwitter

+ (BOOL) initWithConsumerKey:(NSString*) key consumerSecret:(NSString*) secret urlScheme:(NSString*) urlScheme {
    mURLScheme = urlScheme;
    mConsumerKey = key;
    mConsumerSecret = secret;

    /* Check if we already have access token */
    NSString* accessToken = [self accessToken];
    if( accessToken ) {
        [AIR log:@"Initializing STTwitter w/ key, secret and user's access tokens"];
        mTwitter = [STTwitterAPI twitterAPIWithOAuthConsumerKey:key consumerSecret:secret oauthToken:accessToken oauthTokenSecret:[self accessTokenSecret]];
        return YES;
    }
    return NO;
}

+ (void) getAccessTokensForPIN:(NSString*) PIN {
    [AIR log:@"Getting OAuth tokens for PIN"];

    [mTwitter postAccessTokenRequestWithPIN:PIN successBlock:^(NSString* oauthToken, NSString* oauthTokenSecret, NSString* userID, NSString* screenName) {
        [AIR log:@"Successfully retrieved access token"];
        [self storeCredentials:screenName userID:userID accessToken:oauthToken accessTokenSecret:oauthTokenSecret];
        /* Dispatch login success */
        [AIR dispatchEvent:LOGIN_SUCCESS];
    } errorBlock:^(NSError* error) {
        [AIR log:[NSString stringWithFormat:@"Error retrieving access token: %@", error.localizedDescription]];
        [AIR dispatchEvent:LOGIN_ERROR withMessage:error.localizedDescription];
    }];
}

+ (void) verifySystemAccount:(ACAccount*) account {
    [[self api] postReverseOAuthTokenRequest:^(NSString *authenticationHeader) {
        [AIR log:@"Authentication header retrieved."];
        mTwitter = [STTwitterAPI twitterAPIOSWithAccount:account];
        [mTwitter verifyCredentialsWithUserSuccessBlock:^(NSString *username, NSString *userID) {
            [AIR log:@"Credentials for system account are valid."];
            [mTwitter postReverseAuthAccessTokenWithAuthenticationHeader:authenticationHeader successBlock:^(NSString *oAuthToken, NSString *oAuthTokenSecret, NSString *userID, NSString *screenName) {
                [AIR log:@"Access token for authentication header retrieved."];
                [self storeCredentials:username userID:userID accessToken:oAuthToken accessTokenSecret:oAuthTokenSecret];
                /* Dispatch login success */
                [AIR dispatchEvent:LOGIN_SUCCESS];
            } errorBlock:^(NSError *error) {
                [AIR log:[NSString stringWithFormat:@"Error retrieving access token for authentication header: %@", error.localizedDescription]];
                [AIR dispatchEvent:LOGIN_ERROR withMessage:error.localizedDescription];
            }];
        } errorBlock:^(NSError *error) {
            [AIR log:[NSString stringWithFormat:@"Error verifying system account credentials: %@", error.localizedDescription]];
            [AIR dispatchEvent:LOGIN_ERROR withMessage:error.localizedDescription];
        }];
    } errorBlock:^(NSError *error) {
        [AIR log:[NSString stringWithFormat:@"Error retrieving authentication header: %@", error.localizedDescription]];
        [AIR dispatchEvent:LOGIN_ERROR withMessage:error.localizedDescription];
    }];
}

+ (void) storeCredentials:(NSString*) screenName userID:(NSString*) userID accessToken:(NSString*) accessToken accessTokenSecret:(NSString*) accessTokenSecret {
    /* There are not set when logging in after log out so we set them manually */
    [mTwitter setUserName:screenName];
    [mTwitter setUserID:userID];
    /* Store access tokens */
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:accessToken forKey:@"accessToken"];
    [defaults setObject:accessTokenSecret forKey:@"accessTokenSecret"];
    [defaults synchronize];
}

+ (void) clearAccessTokens {
    mTwitter = nil;
    mLoggedInUser = nil;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"accessToken"];
    [defaults removeObjectForKey:@"accessTokenSecret"];
    [defaults synchronize];
}

/**
 *
 *
 * Getters / Setters
 *
 *
 */

+ (STTwitterAPI*) api {
    return [self api:NO];
}

+ (STTwitterAPI*) api:(BOOL) newInstance {
    if( !mTwitter || newInstance ) {
        mTwitter = [STTwitterAPI twitterAPIWithOAuthConsumerKey:mConsumerKey consumerSecret:mConsumerSecret];
    }
    return mTwitter;
}

+ (NSString*) urlScheme {
    return mURLScheme;
}

+ (NSString*) accessToken {
    return [[NSUserDefaults standardUserDefaults] valueForKey:@"accessToken"];
}

+ (NSString*) accessTokenSecret {
    return [[NSUserDefaults standardUserDefaults] valueForKey:@"accessTokenSecret"];
}

/**
 * Logged in user info
 */

+ (AIRTwitterUser*) loggedInUser {
    return mLoggedInUser;
}

+ (void) setLoggedInUser:(AIRTwitterUser*) user {
    mLoggedInUser = user;
}

@end







