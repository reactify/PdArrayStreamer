//
//  AudioEngine.h
//  Tannhauser
//
//  Created by Joe White on 31/12/2013.
//  Copyright (c) 2013 Martin Roth. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>

typedef void (^AudioEngineCallBackBlock)(UInt32            frames,
										 AudioBufferList   *audio);

@interface AudioEngine : NSObject {
	double _sampleRate;
	int _blockSize;
}

@property (readonly) AudioUnit outputUnit;
@property (assign) double startingFrameCount;
@property (assign) int counter;

+ (instancetype)audioEngineWithBlock:(AudioEngineCallBackBlock)block;

- (void)start;
- (void)stop;
- (void)destroy;
- (void)printStreamDescription:(const AudioStreamBasicDescription)asbd;
+ (void)dumpBufferToFile:(NSString *)path buffer:(float *)data numSamples:(int)num;

@end
