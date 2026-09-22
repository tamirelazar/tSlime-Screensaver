#import "Calibration.h"
static void Fill(NSRect r, NSColor *c) { [c setFill]; NSRectFill(r); }
void DrawCalibration(NSRect b, BOOL preview) {
    if (b.size.width <= 0 || b.size.height <= 0) return;
    Fill(b, [NSColor colorWithSRGBRed:.06 green:.08 blue:.10 alpha:1]);
    [NSGraphicsContext saveGraphicsState];
    // A 1920 x 1080 source with four distinct edges, 5% inset and a square.
    NSAffineTransform *t = [NSAffineTransform transform];
    [t scaleXBy:b.size.width/1920 yBy:b.size.height/1080]; [t concat];
    Fill(NSMakeRect(0, 1060, 1920, 20), NSColor.redColor);
    Fill(NSMakeRect(1900, 0, 20, 1080), NSColor.greenColor);
    Fill(NSMakeRect(0, 0, 1920, 20), NSColor.blueColor);
    Fill(NSMakeRect(0, 0, 20, 1080), NSColor.yellowColor);
    [[NSColor colorWithWhite:.35 alpha:1] setStroke];
    NSBezierPath *grid = [NSBezierPath bezierPath]; grid.lineWidth = 2;
    for (int i=1; i<10; i++) {
        [grid moveToPoint:NSMakePoint(i*192, 0)]; [grid lineToPoint:NSMakePoint(i*192,1080)];
        [grid moveToPoint:NSMakePoint(0,i*108)]; [grid lineToPoint:NSMakePoint(1920,i*108)];
    }
    [grid stroke];
    [[NSColor whiteColor] setStroke];
    NSBezierPath *inset = [NSBezierPath bezierPathWithRect:NSMakeRect(96,54,1728,972)];
    inset.lineWidth=8; [inset stroke];
    Fill(NSMakeRect(760,340,400,400), NSColor.magentaColor);
    // The cyan markers locate all four source corners without relying on text.
    for (int x=0;x<2;x++) for(int y=0;y<2;y++)
        Fill(NSMakeRect(x?1740:80,y?900:80,100,100),NSColor.cyanColor);
    NSDictionary *a=@{NSFontAttributeName:[NSFont monospacedSystemFontOfSize:48 weight:NSFontWeightBold],NSForegroundColorAttributeName:NSColor.whiteColor};
    for (int i=1;i<10;i++) {
        [[NSString stringWithFormat:@"%d",i] drawAtPoint:NSMakePoint(i*192-15,1000) withAttributes:a];
        [[NSString stringWithFormat:@"%d",i] drawAtPoint:NSMakePoint(28,i*108-24) withAttributes:a];
    }
    [[NSString stringWithFormat:@"%@  %.0f x %.0f",preview?@"PREVIEW":@"FULL",b.size.width,b.size.height]
        drawAtPoint:NSMakePoint(500,820) withAttributes:a];
    [@"400 x 400" drawAtPoint:NSMakePoint(790,270) withAttributes:a];
    [@"5% INSET" drawAtPoint:NSMakePoint(780,130) withAttributes:a];
    [NSGraphicsContext restoreGraphicsState];
}
