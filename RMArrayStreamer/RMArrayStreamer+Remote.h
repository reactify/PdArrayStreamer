//
//  RMArrayStreamer+Remote.h
//  RMArrayStreamer
//
//  Created by Ragnar Hrafnkelsson on 19/10/2014.
//  Copyright (c) 2014 Reactify. All rights reserved.
//

#import "RMArrayStreamer.h"

@class NSError;

@interface RMArrayStreamer (Remote)

+ (void)downloadFile:(NSURL *)url
			  toPath:(NSString *)path
		  completion:(void(^)(void))completion
			  update:(void(^)(unsigned long long size, unsigned long long total))update
			  failed:(void(^)(NSError *error))failed;

@end
