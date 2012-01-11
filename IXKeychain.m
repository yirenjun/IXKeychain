//
//  Keychain.m
//  DishFreely
//
//  Created by Luke Freeman on 10/6/11.
//  Copyright (c) 2011 Luke Freeman. All rights reserved.
//
//  Based on Keychain class from the OpenStack (Rackspace) project
//	https://github.com/rackspace/rackspace-ios
//

#import "IXKeychain.h"
#import <Security/Security.h>

@interface Keychain ()

+ (NSString *)serviceName;
+ (NSString *)appName;
+ (NSString *)normalizeKey:(NSString *)aKey;

+ (NSMutableDictionary *)dictionaryBaseForKey:(NSString *)aKey;
+ (NSMutableDictionary *)dictionaryBaseForKey:(NSString *)aKey skipClass:(BOOL)aSkipClass;

@end

@implementation Keychain

+ (NSString *)serviceName {
	return @"service";
}

+ (NSString *)appName {    
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    
	// Attempt to find a name for this application
	NSString *appName = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	if (!appName) {
		appName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];	
	}
	
    return appName;
}


+ (NSString *)normalizeKey:(NSString *)aKey {
	return [NSString stringWithFormat:@"%@.%@", [Keychain appName], aKey];
}

+ (NSMutableDictionary *)dictionaryBaseForKey:(NSString *)aKey {
	return [Keychain dictionaryBaseForKey:aKey skipClass:NO];
}

+ (NSMutableDictionary *)dictionaryBaseForKey:(NSString *)aKey skipClass:(BOOL)aSkipClass {
	
	NSMutableDictionary *searchDictionary = [NSMutableDictionary new];
	
	[searchDictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
	[searchDictionary setObject:[Keychain serviceName] forKey:(__bridge id)kSecAttrService];
	[searchDictionary setObject:aKey forKey:(__bridge id)kSecAttrAccount];	
	
    return searchDictionary; 
}


+ (OSStatus)valueStatusForKey:(NSString *)aKey {
	NSDictionary *searchDictionary = [Keychain dictionaryBaseForKey:aKey];
	return SecItemCopyMatching((__bridge CFDictionaryRef)searchDictionary, nil);
}

+ (BOOL)hasValueForKey:(NSString *)aKey {
	return ([Keychain valueStatusForKey:aKey] == errSecSuccess);
}


// NOTE: aValue or any sub objects must conform to the NSCoding protocol
+ (BOOL)setSecureValue:(id)aValue forKey:(NSString *)aKey {

	if (aValue == nil || aKey == nil) return NO;
    
	NSData *valueData = [NSKeyedArchiver archivedDataWithRootObject:aValue];
	
	aKey = [Keychain normalizeKey:aKey];
	NSLog(@"storing value for key: '%@'", aKey);
    
	// check the status of the value (exists / doesn't)
	OSStatus valStatus = [Keychain valueStatusForKey:aKey];
	if (valStatus == errSecItemNotFound) {

		// doesn't exist .. create
		NSMutableDictionary *addQueryDict = [Keychain dictionaryBaseForKey:aKey];
		[addQueryDict setObject:valueData forKey:(__bridge id)kSecValueData];
            
		valStatus = SecItemAdd ((__bridge CFDictionaryRef)addQueryDict, NULL);
		NSAssert1(valStatus == errSecSuccess, @"Value add returned status %d", valStatus);
	} 
	else if (valStatus == errSecSuccess) {

		// exists .. update
		NSMutableDictionary *updateQueryDict = [Keychain dictionaryBaseForKey:aKey];
		NSDictionary *valueDict = [NSDictionary dictionaryWithObject:valueData forKey:(__bridge id)kSecAttrGeneric];
		
		valStatus = SecItemUpdate ((__bridge CFDictionaryRef)updateQueryDict, (__bridge CFDictionaryRef)valueDict);
		NSAssert1(valStatus == errSecSuccess, @"Value update returned status %d", valStatus);
		
	} 
	else {
		NSAssert2(NO, @"Received mismatched status (%d) while setting keychain value for key %@", valStatus, aKey);
	}
	
	return YES;
}

+ (id)secureValueForKey:(NSString *)aKey {

    aKey = [Keychain normalizeKey:aKey];
    
	NSMutableDictionary *retrieveQueryDict = [Keychain dictionaryBaseForKey:aKey];
	[retrieveQueryDict setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];		// make sure data comes back
	
	CFDataRef dataRef = nil;
	OSStatus queryResult = SecItemCopyMatching ((__bridge CFDictionaryRef)retrieveQueryDict, (CFTypeRef *)&dataRef);
	
	NSData *valueData = (__bridge_transfer NSData *)dataRef;

	if (queryResult == errSecSuccess) {
		id value = [NSKeyedUnarchiver unarchiveObjectWithData:valueData];
		return value;
	} 
	else {
		NSAssert2(queryResult == errSecItemNotFound, @"Received mismatched status (%d) while retriveing keychain value for key %@", queryResult, aKey);
	}		
	
	return nil;
}

+ (BOOL)removeSecureValueForKey:(NSString *)aKey {

	aKey = [Keychain normalizeKey:aKey];
	
	NSDictionary *deleteQueryDict = [Keychain dictionaryBaseForKey:aKey];
    OSStatus queryResult = SecItemDelete((__bridge CFDictionaryRef)deleteQueryDict);
	if (queryResult == errSecSuccess) {
		return YES;
	}
	else {
		NSAssert2(queryResult == errSecItemNotFound, @"Received mismatched status (%d) while deleting keychain value for key %@", queryResult, aKey);
		return NO;
	}
}

@end