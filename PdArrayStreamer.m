#import "PdArrayStreamer.h"

@implementation PdArrayStreamer

- (id)initWithTableNameForLeftChannel:(NSString *)larrayName andRightChannel:(NSString *)rarrayName {
  self = [super init];
  if (self != nil) {
    leftArrayName = [larrayName retain];
    rightArrayName = [rarrayName retain];
  }
  return self;
}

- (void)dealloc {
  [leftArrayName release];
  [rightArrayName release];
  [super dealloc];
}

- (void)startStreamingFromUrl:(NSURL *)url {
  NSString *tempDownloadPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"temp.mp3"];
  ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
  [request setDownloadDestinationPath:tempDownloadPath];
  
//  [request setDataReceivedBlock:^(NSData *data) {
//    // TODO(mhroth): if this is filled in, then the data must be written to file manually
//    NSLog(@"Received data %i bytes.", [data length]);
//  }];
  
  [request setCompletionBlock:^{
    NSLog(@"File successfully downloaded!");
    
    NSError *error = nil;
    
    // create the AVAsset
    NSURL *fileUrl = [NSURL fileURLWithPath:tempDownloadPath];
    AVAsset *avAsset = [AVURLAsset URLAssetWithURL:fileUrl options:nil];
    
    // get the number of channels (and other stream descriptors)
    NSArray *tracks = [avAsset tracksWithMediaType:AVMediaTypeAudio];
    AVAssetTrack *assetTrack = [tracks objectAtIndex:0];
    const CMFormatDescriptionRef formatDescr = (CMFormatDescriptionRef) [assetTrack.formatDescriptions objectAtIndex:0];
    const AudioStreamBasicDescription *basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescr);
    int numChannels = basicDescription->mChannelsPerFrame;
    
    // creaet the AVAssetReader
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:avAsset error:&error];
    
    if (error != nil) NSLog(@"error: %@", error);
    
      float sampleRate = 44100.0;
      
    // decode the asset to kAudioFormatLinearPCM, Pd's sampleRate, 16bit, interleaved  
  NSMutableDictionary *outputSettings = [NSMutableDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
      [NSNumber numberWithFloat:sampleRate], AVSampleRateKey,
      [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
      [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
      [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
      [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
      nil];
    
    // tell the AVAssetReader which output track it should decode
    AVAssetReaderOutput *assetReaderOutput = [AVAssetReaderTrackOutput
        assetReaderTrackOutputWithTrack:[avAsset.tracks objectAtIndex:0]
        outputSettings:outputSettings];
    [assetReader addOutput:assetReaderOutput];
    
    // start reading!
    [assetReader startReading];
    
    int numDecompressedFrames = 0;
    while (true) { // keep going as long as we have work to do!
      switch (assetReader.status) {
        case AVAssetReaderStatusReading: {
          AVAssetReaderTrackOutput *trackOutput =
              (AVAssetReaderTrackOutput *) [assetReader.outputs objectAtIndex:0];
          
          // decompress the received frames
          CMSampleBufferRef sampleBufferRef = [trackOutput copyNextSampleBuffer];
          CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
          size_t length = CMBlockBufferGetDataLength(blockBufferRef); // number of bytes
            if (length <=0) return;
          char buffer[length];
          CMBlockBufferCopyDataBytes(blockBufferRef, 0, length, buffer);
          CMSampleBufferInvalidate(sampleBufferRef);
          CFRelease(sampleBufferRef);
          
          // copy the frames into Pd
          const int numFrames = length/sizeof(short)/numChannels;
          float floatBuffer[numFrames];
          switch (numChannels) {
            default: break; // TODO(mhroth): handle channel counts other than 1 or 2
            case 2: {
              // convert the decompressed interleaved short samples to uninterleaves floats
              vDSP_vflt16(((short *) buffer)+1, numChannels, floatBuffer, 1, numFrames);
              const float a = 0.000030517578125f;
              vDSP_vsmul(floatBuffer, 1, &a, floatBuffer, 1, numFrames);
              
              // copy the buffer to Pd
              [PdBase copyArray:floatBuffer toArrayNamed:rightArrayName
                  withOffset:numDecompressedFrames count:numFrames];
              // allow fallthrough
            }
            case 1: {
              vDSP_vflt16((short *) buffer, numChannels, floatBuffer, 1, numFrames);
              const float a = 0.000030517578125f;
              vDSP_vsmul(floatBuffer, 1, &a, floatBuffer, 1, numFrames);
              [PdBase copyArray:floatBuffer toArrayNamed:leftArrayName
                  withOffset:numDecompressedFrames count:numFrames];
            }
            case 0: break;
          }
          
          // increment the number of decompressed frames (i.e. increment the table offset)
          numDecompressedFrames += numFrames;
          break;
        }
        case AVAssetReaderStatusCompleted: {
          // TODO(mhroth): inform someone!
          return;
        }
        case AVAssetReaderStatusCancelled: {
          // TODO(mhroth): inform someone!
          return;
        }
        case AVAssetReaderStatusFailed: {
          // TODO(mhroth): inform someone!
          return;
        }
        default:
        case AVAssetReaderStatusUnknown: {
          // TODO(mhroth): inform someone!
          return;
        }
      }
    }
  }];
  
  [request setFailedBlock:^{
    // TODO
    NSLog(@"File download fail: %@", [request error]);
  }];
  
  // start download and decompression!
  [request startAsynchronous];
}

@end

//int main(void) {
//  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
//  PdArrayStreamer *streamer = [[PdArrayStreamer alloc] initWithTableNameForLeftChannel:@"left" andRightChannel:@"right"];
//  [streamer startStreamingFromUrl:[NSURL URLWithString:@""] withUpdateBlock:^(int totalFrames, int numFrames) {
//    NSLog(@"totalFrames %i, numFrames %i", totalFrames, numFrames);
//  }];
//  [streamer release];
//  [pool release];
//}
