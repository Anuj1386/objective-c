//
//  TimeOutTest.m
//  pubnub
//
//  Created by Valentin Tuller on 9/18/13.
//  Copyright (c) 2013 PubNub Inc. All rights reserved.
//

#import "TimeOutTest.h"
#import "PubNub.h"
#import "PubNub+Protected.h"
#import "PNConfiguration.h"
#import "PNWriteBuffer.h"
#import "PNConstants.h"
#import "PNConnection.h"
#import "PNHereNowResponseParser.h"
#import "Swizzler.h"

@interface TimeOutTest () <PNDelegate>
{
	NSArray *pnChannels;
	NSArray *pnChannelsBad;
	dispatch_semaphore_t semaphoreNotification;
	BOOL subscriptionDidFailWithErrorCalled;
	BOOL notificationParticipantsListCalled;
	BOOL notificationFailHistoryDownloadCalled;
	BOOL notificationFailMessageSendCalled;
	BOOL notificationTokenReceiveDidFailCallled;
}

@end

@implementation TimeOutTest

-(NSNumber *)shouldReconnectPubNubClient:(id)object {
	return [NSNumber numberWithBool: NO];
}


- (void)setUp
{
    [super setUp];
	semaphoreNotification = dispatch_semaphore_create(0);
	pnChannels = [PNChannel channelsWithNames:@[@"iosdev", @"andoirddev"]];
	[self resetConnection];
//	[PubNub disconnect];
//    [PubNub setDelegate:self];
//
//	PNConfiguration *configuration = [PNConfiguration configurationForOrigin:@"pubsub.pubnub.com" publishKey:@"demo" subscribeKey:@"demo" secretKey: nil cipherKey: nil];
//    [PubNub setConfiguration: configuration];
//	[PubNub sharedInstance].configuration.autoReconnectClient = NO;
////	[PubNub sharedInstance].restoringConnection = NO;
//    [PubNub connectWithSuccessBlock:^(NSString *origin) {
//
//        PNLog(PNLogGeneralLevel, nil, @"{BLOCK} PubNub client connected to: %@", origin);
////		[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 30.0] ];
//		[PubNub sharedInstance].configuration.autoReconnectClient = NO;
//    }
//      errorBlock:^(PNError *connectionError) {
//		  PNLog(PNLogGeneralLevel, nil, @"connectionError %@", connectionError);
//	}];
}

//subscriptionRequestTimeout
- (void)pubnubClient:(PubNub *)client subscriptionDidFailWithError:(NSError *)error {
    PNLog(PNLogGeneralLevel, self, @"PubNub client failed to subscribe because of error: %@", error);
	subscriptionDidFailWithErrorCalled = YES;
}

- (void)pubnubClient:(PubNub *)client didSubscribeOnChannels:(NSArray *)channels {
    PNLog(PNLogGeneralLevel, self, @"PubNub client successfully subscribed on channels: %@", channels);
}

-(void)resetConnection {
	[PubNub resetClient];
	int64_t delayInSeconds = 2;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
	dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {

		[PubNub setDelegate:self];
		[PubNub setConfiguration: [PNConfiguration defaultConfiguration]];

		[PubNub connectWithSuccessBlock:^(NSString *origin) {

			PNLog(PNLogGeneralLevel, nil, @"\n\n\n\n\n\n\n{BLOCK} PubNub client connected to: %@", origin);
			dispatch_semaphore_signal(semaphore);
		}
							 errorBlock:^(PNError *connectionError) {
								 PNLog(PNLogGeneralLevel, nil, @"connectionError %@", connectionError);
								 dispatch_semaphore_signal(semaphore);
								 STFail(@"connectionError %@", connectionError);
							 }];
	});
	while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
								 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5]];
	BOOL isConnected = [[PubNub sharedInstance] isConnected];
	STAssertTrue( isConnected, @"connect fail");
}

- (void)test20SubscriptionRequestTimeout
{
	[self resetConnection];

	__block NSDate *start = [NSDate date];
	__block BOOL isCompletionBlockCalled = NO;
	subscriptionDidFailWithErrorCalled = NO;

	SwizzleReceipt *receipt = [self setFakeReadStreamContent];

	[PubNub subscribeOnChannels: pnChannels
	withCompletionHandlingBlock:^(PNSubscriptionProcessState state, NSArray *channels, PNError *subscriptionError)
	 {
		 isCompletionBlockCalled = YES;
		 NSTimeInterval interval = -[start timeIntervalSinceNow];
		 STAssertEqualsWithAccuracy( interval, [PubNub sharedInstance].configuration.subscriptionRequestTimeout, 2, @"Timeout [PubNub sharedInstance].configuration.subscriptionRequestTimeout no correct, %d instead of %d", interval, [PubNub sharedInstance].configuration.subscriptionRequestTimeout);
		 STAssertNotNil( subscriptionError, @"subscriptionError must be not nil");
	 }];
	for( int i=0; i<[PubNub sharedInstance].configuration.subscriptionRequestTimeout+1 &&
		isCompletionBlockCalled == NO && subscriptionDidFailWithErrorCalled == NO; i++ )
		[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0] ];
	[Swizzler unswizzleFromReceipt:receipt];
	STAssertTrue(isCompletionBlockCalled, @"Completion block not called");
	STAssertTrue(subscriptionDidFailWithErrorCalled, @"Notification not called");
}

//nonSubscriptionRequestTimeout
- (void)pubnubClient:(PubNub *)client didFailParticipantsListDownloadForChannel:(PNChannel *)channel withError:(PNError *)error {
    PNLog(PNLogGeneralLevel, self, @"PubNub client failed to download participants list for channel %@ because of error: %@",
          channel, error);
	notificationParticipantsListCalled = YES;
}
- (void)test30ParticipantsListForChannelTimeout
{
	[self resetConnection];

	SwizzleReceipt *receipt = [self setFakeReadStreamContent];

	notificationParticipantsListCalled = NO;
	for( int i=0; i<pnChannels.count; i++ )
	{
		__block NSDate *start = [NSDate date];
		__block BOOL isCompletionBlockCalled = NO;
		
		[PubNub requestParticipantsListForChannel:pnChannels[i]
							  withCompletionBlock:^(NSArray *udids, PNChannel *channel, PNError *error)
		{
			isCompletionBlockCalled = YES;
			NSTimeInterval interval = -[start timeIntervalSinceNow];
		    PNLog(PNLogGeneralLevel, self, @"test30ParticipantsListForChannelTimeout %f", interval);

			STAssertEqualsWithAccuracy( interval, [PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout, 2, @"Timeout [PubNub sharedInstance].configuration.subscriptionRequestTimeout no correct, %d instead of %d", interval, [PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout);
			STAssertNotNil( error, @"requestParticipantsList error must be not nil");
		}];
		for( int j=0; j<[PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout+10 &&
			isCompletionBlockCalled == NO && notificationParticipantsListCalled == NO; j++ )
			[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0] ];
		STAssertTrue(isCompletionBlockCalled, @"Completion block not called");
		STAssertTrue(notificationParticipantsListCalled, @"Notification not called");
	}
	[Swizzler unswizzleFromReceipt:receipt];
}

- (void)test30ParticipantsListForChannelTimeout1
{
	for( int i=0; i<pnChannels.count; i++ )
	{
		[self resetConnection];

		SwizzleReceipt *receipt = [self setFakeReadStreamContent];

		notificationParticipantsListCalled = NO;

		__block NSDate *start = [NSDate date];
		__block BOOL isCompletionBlockCalled = NO;

		[PubNub requestParticipantsListForChannel:pnChannels[i]
							  withCompletionBlock:^(NSArray *udids, PNChannel *channel, PNError *error)
		 {
			 isCompletionBlockCalled = YES;
			 NSTimeInterval interval = -[start timeIntervalSinceNow];
		     PNLog(PNLogGeneralLevel, self, @"test30ParticipantsListForChannelTimeout1 %f", interval);
			 STAssertEqualsWithAccuracy( interval, [PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout, 2, @"Timeout [PubNub sharedInstance].configuration.subscriptionRequestTimeout no correct, %d instead of %d", interval, [PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout);
			 STAssertNotNil( error, @"requestParticipantsList error must be not nil");
		 }];
		for( int j=0; j<[PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout+1 &&
			isCompletionBlockCalled == NO && notificationParticipantsListCalled == NO; j++ )
			[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0] ];
		STAssertTrue(isCompletionBlockCalled, @"Completion block not called");
		STAssertTrue(notificationParticipantsListCalled, @"Notification not called");

		[Swizzler unswizzleFromReceipt:receipt];
	}
}

//history timeout
- (void)pubnubClient:(PubNub *)client didFailHistoryDownloadForChannel:(PNChannel *)channel withError:(PNError *)error
{
	notificationFailHistoryDownloadCalled = YES;
}

- (void)test40RequestHistoryForChannelTimeout
{
	for( int i=0; i<pnChannels.count; i++ )
	{
		[self resetConnection];

		SwizzleReceipt *receipt = [self setFakeReadStreamContent];

		notificationFailHistoryDownloadCalled = NO;

		__block NSDate *start = [NSDate date];
		__block BOOL isCompletionBlockCalled = NO;

		[PubNub requestHistoryForChannel: pnChannels[i]
									from: nil 
									  to: nil
								   limit: 0
						  reverseHistory: NO
					 withCompletionBlock:^(NSArray *messages,
										   PNChannel *channel,
										   PNDate *startDate,
										   PNDate *endDate,
										   PNError *error)
		 {
			 isCompletionBlockCalled = YES;
			 NSTimeInterval interval = -[start timeIntervalSinceNow];
		     PNLog(PNLogGeneralLevel, self, @"test40RequestHistoryForChannelTimeout %f", interval);
			 STAssertEqualsWithAccuracy( interval, [PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout, 1, @"Timeout [PubNub sharedInstance].configuration.subscriptionRequestTimeout no correct, %d instead of %d", interval, [PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout);
			 STAssertNotNil( error, @"requestParticipantsList error must be not nil");
		 }];
		for( int j=0; j<[PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout+1 &&
			isCompletionBlockCalled == NO && notificationFailHistoryDownloadCalled == NO; j++ )
			[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0] ];
		STAssertTrue(isCompletionBlockCalled, @"Completion block not called");
		STAssertTrue(notificationFailHistoryDownloadCalled, @"Notification not called");
		[Swizzler unswizzleFromReceipt:receipt];
	}
}

//message timeout
- (void)pubnubClient:(PubNub *)client didFailMessageSend:(PNMessage *)message withError:(PNError *)error {
	notificationFailMessageSendCalled = YES;
}

- (void)test50SendMessageTimeout
{
	for( int i=0; i<pnChannels.count; i++ )
	{
		[self resetConnection];

		__block BOOL isCompletionBlockCalled = NO;
		[PubNub subscribeOnChannels: @[pnChannels[i]]
		withCompletionHandlingBlock:^(PNSubscriptionProcessState state, NSArray *channels, PNError *subscriptionError)
		 {
			 isCompletionBlockCalled = YES;
		 }];
		for( int i=0; i<[PubNub sharedInstance].configuration.subscriptionRequestTimeout+1 &&
			isCompletionBlockCalled == NO; i++ )
			[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0] ];


		isCompletionBlockCalled = NO;
		notificationFailMessageSendCalled = NO;

		__block NSDate *start = [NSDate date];

		[PubNub sendMessage:@"Hello PubNub" toChannel:pnChannels[i]
									  withCompletionBlock:^(PNMessageState messageSendingState, id data) {
			if( messageSendingState == PNMessageSending)
				return;
			 isCompletionBlockCalled = YES;
			 NSTimeInterval interval = -[start timeIntervalSinceNow];
		     PNLog(PNLogGeneralLevel, self, @"test50SendMessageTimeout %f", interval);
			 STAssertEqualsWithAccuracy( interval, [PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout, 1, @"Timeout [PubNub sharedInstance].configuration.subscriptionRequestTimeout no correct, %d instead of %d", interval, [PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout);
			 STAssertFalse(messageSendingState==PNMessageSent, @"messageSendingState==PNMessageSent %@", data);
		 }];
		SwizzleReceipt *receipt = [self setFakeReadStreamContent];
		for( int j=0; j<[PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout+10 &&
			isCompletionBlockCalled == NO && notificationFailMessageSendCalled == NO; j++ )
			[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0] ];
		STAssertTrue(isCompletionBlockCalled, @"Completion block not called");
		STAssertTrue(notificationFailMessageSendCalled, @"Notification not called");

		[Swizzler unswizzleFromReceipt:receipt];
	}
}

//timeToken timeout
- (void)pubnubClient:(PubNub *)client timeTokenReceiveDidFailWithError:(PNError *)error {
    PNLog(PNLogGeneralLevel, self, @"PubNub client failed to receive time token because of error: %@", error);
	notificationTokenReceiveDidFailCallled = YES;
}

-(void)test60RequestServerTimeTimeout
{
	[self resetConnection];

	SwizzleReceipt *receipt = [self setFakeReadStreamContent];

	notificationTokenReceiveDidFailCallled = NO;
	__block NSDate *start = [NSDate date];
	__block BOOL isCompletionBlockCalled = NO;
	[PubNub requestServerTimeTokenWithCompletionBlock:^(NSNumber *timeToken, PNError *error)
	{
		 isCompletionBlockCalled = YES;
		 NSTimeInterval interval = -[start timeIntervalSinceNow];
		 STAssertEqualsWithAccuracy( interval, [PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout, 2, @"Timeout [PubNub sharedInstance].nonSubscriptionRequestTimeout no correct, %d instead of %d", interval, [PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout);
		 STAssertNotNil( error, @"error must be not nil");
	}];
	for( int i=0; i<[PubNub sharedInstance].configuration.nonSubscriptionRequestTimeout+1 &&
		isCompletionBlockCalled == NO && notificationTokenReceiveDidFailCallled == NO; i++ )
		[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0] ];
	[Swizzler unswizzleFromReceipt:receipt];
	STAssertTrue(isCompletionBlockCalled, @"Completion block not called");
	STAssertTrue(notificationTokenReceiveDidFailCallled, @"Notification not called");
}

//return [Swizzler swizzleSelector:@selector(parsedData)
//			 forInstancesOfClass:[PNHereNowResponseParser class]
//
//return [Swizzler swizzleSelector:@selector(handleReadStreamHasData)
//			 forInstancesOfClass:[PNConnection class]

-(SwizzleReceipt*)setFakeReadStreamContent {
	return [Swizzler swizzleSelector:@selector(isNeedReturnAfterRead)
				 forInstancesOfClass:[PNConnection class]
						   withBlock:
			^(id self, SEL sel){
				PNLog(PNLogGeneralLevel, nil, @"PNConnection isNeedReturnAfterRead");
				return YES;
			}];
}



@end
