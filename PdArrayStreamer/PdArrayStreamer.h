#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import "ASIHTTPRequest.h"
#import "PdBase.h"

// http://stackoverflow.com/questions/6242131/using-avassetreader-to-read-stream-from-a-remote-asset

@interface PdArrayStreamer : NSObject {
  NSString *leftArrayName;
  NSString *rightArrayName;
}

- (id)initWithTableNameForLeftChannel:(NSString *)larrayName andRightChannel:(NSString *)rarrayName;

- (void)startStreamingFromUrl:(NSURL *)url;

@end
