//
//  RMArrayStreamer+Remote.m
//  RMArrayStreamer
//
//  Created by Ragnar Hrafnkelsson on 19/10/2014.
//  Copyright (c) 2014 Reactify. All rights reserved.
//

#import "RMArrayStreamer+Remote.h"

@implementation RMArrayStreamer (Remote)

+ (void)downloadFile:(NSURL *)url
			  toPath:(NSString *)path
		  completion:(void(^)(void))completion
			  update:(void(^)(unsigned long long size, unsigned long long total))update
			  failed:(void(^)(NSError *error))failed
{
	NSLog(@"%s not implemented", __func__);
	
	// TODO // NSURLConnection
	
	//	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
	//
	//	[request setDownloadDestinationPath:path];
	//	[request setCompletionBlock:completion];
	//	[request setBytesReceivedBlock:update];
	//
	//	[request setFailedBlock:^{
	//	failed([request error]);
	//	}];
	//
	//	// start download and decompression!
	//	[request startAsynchronous];
}

@end
