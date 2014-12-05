//
//  RMStreamingPlayer.m
//  RMArrayStreamer
//
//  Created by Ragnar Hrafnkelsson on 19/10/2014.
//  Copyright (c) 2014 Reactify. All rights reserved.
//

#import <AVFoundation/AVAssetReader.h>

#import "RMStreamingPlayer.h"
#import "RMArrayStreamer.h"


static const int ARRAY_SIZE = 147456;


@interface RMStreamingPlayer ()

@property (nonatomic, assign) int readPosition;
@property (nonatomic, assign) int arraySize;
@property (nonatomic, strong) RMArrayStreamer *arrayStreamer;

@end


@implementation RMStreamingPlayer

- (void)dealloc
{
	_arrayStreamer = nil;
}

- (instancetype)initWithFile:(NSURL *)url
{
	self = [super init];
	if (!self) return nil;
	
	_arrayStreamer = [[RMArrayStreamer alloc] initWithArraySize:ARRAY_SIZE];
	[_arrayStreamer startDecompressingFromUrl:url
					   withDecompressCallback:^(RMArrayStreamerStatus status, int numDecompressedFrames)
	{
		if (status == RMArrayStreamerStatusCompleted) _isPlaying = NO; // TODO: Make sure it reads last chunk
		
		_isLoaded = YES;
		_readPosition = 0;
		_channelCount = _arrayStreamer.channelCount;
	}];
	
	_arraySize = _arrayStreamer.arraySize;
	
	return self;
}

void RMStreamingPlayerProcess(__unsafe_unretained RMStreamingPlayer *THIS, float *lBuffer, float *rBuffer, int bufferSize)
{
	if (!THIS->_isPlaying || !THIS->_isLoaded) return;
	
	// if this is the last buffer available, start preparing next chunk
	if (THIS->_readPosition + bufferSize >= THIS->_arraySize) loadNextBuffer(THIS);
	
	if (THIS->_channelCount == 2) // Only supports stereo for now
	{
		int offset = THIS->_readPosition;
			
		memcpy(lBuffer, THIS->_arrayStreamer->_leftBuffer  + offset, bufferSize * sizeof(float));
		memcpy(rBuffer, THIS->_arrayStreamer->_rightBuffer + offset, bufferSize * sizeof(float));
	}
	else
	{
		memset(lBuffer, 0, bufferSize * sizeof(float));
		memset(rBuffer, 0, bufferSize * sizeof(float));
	};

	THIS->_readPosition += bufferSize; // advance through buffer
}

static void loadNextBuffer(__unsafe_unretained RMStreamingPlayer *THIS)
{
	THIS->_isLoaded = NO;
	[THIS->_arrayStreamer continueDecompression];
}

@end
