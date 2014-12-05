//
//  AppDelegate.m
//  test
//
//  Created by Ragnar Hrafnkelsson on 19/10/2014.
//  Copyright (c) 2014 test. All rights reserved.
//

#import "AppDelegate.h"
#import "AudioEngine.h"
#import "RMStreamingPlayer.h"
#import "RMArrayStreamer.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@property (strong) AudioEngine *audioEngine;
@property (strong) RMStreamingPlayer *streamingPlayer;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	NSURL *fileURL = [[NSBundle mainBundle] URLForResource:@"temp" withExtension:@"mp3"];
	self.streamingPlayer = [[RMStreamingPlayer alloc] initWithFile:fileURL];
	self.streamingPlayer.isPlaying = YES;
	
	self.audioEngine = [AudioEngine audioEngineWithBlock:^(UInt32 frames, AudioBufferList *audio)
	{
		float *lBuffer = (float *) audio->mBuffers[0].mData;
		float *rBuffer = (float *) audio->mBuffers[1].mData;
		
		RMStreamingPlayerProcess(_streamingPlayer, lBuffer, rBuffer, frames);
	}];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self.audioEngine start];
	});

}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
	_streamingPlayer = nil;
	_audioEngine = nil;
}

@end
