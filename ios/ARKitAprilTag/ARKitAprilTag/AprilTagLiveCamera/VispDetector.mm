#import "VispDetector.h"
#import "ImageConversion.h"
#import "ImageDisplayWithContext.h"

vpDetectorAprilTag detector(vpDetectorAprilTag::TAG_36h11, vpDetectorAprilTag::HOMOGRAPHY_VIRTUAL_VS);

@implementation VispDetector

- (NSDictionary *)detectAprilTag:(UIImage *)image px:(float)px py:(float)py {

    // make vpImage for the detection.
    vpImage<unsigned char> I = [ImageConversion vpImageGrayFromUIImage:image];

    float u0 = I.getWidth()/2;
    float v0 = I.getHeight()/2;

    // in case, intrinsic parameter is not worked.
    if(px == 0.0 && py == 0.0){
        px = 1515.0;
        py = 1515.0;
    }

    // AprilTag detections setting
    float quadDecimate = 3.0;
    int nThreads = 1;
    double tagSize = 0.03; // meter
    detector.setAprilTagQuadDecimate(quadDecimate);
    detector.setAprilTagNbThreads(nThreads);

    // Detection.
    vpCameraParameters cam;
    cam.initPersProjWithoutDistortion(px,py,u0,v0);
    std::vector<vpHomogeneousMatrix> cMo_vec;
    detector.detect(I, tagSize, cam, cMo_vec);

    // starts drawing
    UIGraphicsBeginImageContext(image.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    // draw original image in the current context.
    [image drawAtPoint:CGPointMake(0,0)];

    // draw frames by each tag.
    int tagNums = (int) detector.getNbObjects();
    NSMutableArray *tagsData = [NSMutableArray array];
    for(int i=0; i < tagNums; i++){

        // parameters
        std::vector<vpImagePoint> polygon = detector.getPolygon(i);
        vpImagePoint cog = detector.getCog(i);
        vpTranslationVector trans = cMo_vec[i].getTranslationVector();
        UIColor *mainColor = [UIColor blueColor];
        int tagLineWidth = 10;

        // tag Id from message: "36h11 id: 1" -> 1
        NSString * message = [NSString stringWithCString:detector.getMessage(i).c_str() encoding:[NSString defaultCStringEncoding]];
        NSArray *phases = [message componentsSeparatedByString:@" "];
        int detectedTagId = [phases[2] intValue];

        // draw tag id
        NSString *tagIdStr = [NSString stringWithFormat:@"%d", detectedTagId];
        [ImageDisplay displayText:tagIdStr :polygon[0].get_u() :polygon[0].get_v() - 50 :600 :100 :mainColor :[UIColor clearColor]];

        // draw tag frame
        [ImageDisplay displayLineWithContext:context :polygon :mainColor :tagLineWidth];

        // draw xyz coordinate.
        [ImageDisplay displayFrameWithContext:context :cMo_vec[i] :cam :tagSize :6];

        // draw distance from camera.
        NSString *meter = [NSString stringWithFormat:@"(%.2f,%.2f,%.2f)",trans[0],trans[1],trans[2]];
        [ImageDisplay displayText:meter :cog.get_u() :cog.get_v() +50 :600 :100 :[UIColor whiteColor] :[UIColor blueColor]];

        // Add tag data to the array
        NSDictionary *tagData = @{
            @"id": @(detectedTagId),
            @"x": @(trans[0]),
            @"y": @(trans[1]),
            @"z": @(trans[2])
        };
        [tagsData addObject:tagData];
    }

    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    NSDictionary *result = @{
        @"image": resultImage,
        @"tagNums": @(tagNums),
        @"tagsData": tagsData // Include the position data of tags
    };
    return result;
}

@end
