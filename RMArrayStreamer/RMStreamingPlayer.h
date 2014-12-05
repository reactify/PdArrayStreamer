//
//  RMStreamingPlayer.h
//  RMArrayStreamer
//
//  Created by Ragnar Hrafnkelsson on 19/10/2014.
//  Copyright (c) 2014 Reactify. All rights reserved.
//

#import <Foundation/NSObject.h>

@class NSURL;

@interface RMStreamingPlayer : NSObject

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign, readonly) BOOL isLoaded;
@property (nonatomic, assign, readonly) int channelCount;

- (instancetype)initWithFile:(NSURL *)url;

void RMStreamingPlayerProcess(__unsafe_unretained RMStreamingPlayer *THIS, float *lBuffer, float *rBuffer, int bufferSize);

@end
