#import "Calibration.h"
int main(int argc, const char **argv) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1920 pixelsHigh:1080 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
        DrawCalibration(NSMakeRect(0,0,1920,1080),NO);
        [NSGraphicsContext restoreGraphicsState];
        [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:@(argv[1]) atomically:YES];
    }
}
