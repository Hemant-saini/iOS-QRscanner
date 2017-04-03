//
//  ViewController.m
//  QRCodeReader
//
//  Created by Hemant Saini on 21/03/17.
//  Copyright © 2017 Hemant Saini. All rights reserved.
//

#import "ViewController.h"
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController () <AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic) BOOL isReading;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@property (nonatomic, weak) IBOutlet UIView *resultImageView;
@property (nonatomic, weak) IBOutlet UILabel *showBarCodeStatus;
@property (nonatomic, weak) IBOutlet UILabel *showBarCodeValue;
@property (nonatomic, weak) IBOutlet UIButton *btnStart;

- (IBAction)startScanningButton:(id)sender;

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"QR code Scanner";
    self.showBarCodeValue.text = @"Tap Above to Copy to Clipboard";
    self.showBarCodeStatus.userInteractionEnabled = YES;
    self.showBarCodeStatus.text = @"https://fb.com/";
    
    UITapGestureRecognizer *singleFingerTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(handleSingleTap:)];
    [self.showBarCodeStatus addGestureRecognizer:singleFingerTap];
}

#pragma mark - Camera scanning
- (IBAction)startScanningButton:(id)sender {
    self.isReading ? [self stopReading] : [self startReading];
    self.isReading = !self.isReading;
    
}

- (BOOL)startReading {
    NSError *error;
    [self showBarCodeValue];
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (!input) {
        NSLog(@"%@", [error localizedDescription]);
        return NO;
    }
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession addInput:input];
    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [self.captureSession addOutput:captureMetadataOutput];
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create("myQueue", NULL);
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    [captureMetadataOutput setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]];
    self.videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [self.videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [self.videoPreviewLayer setFrame:self.resultImageView.layer.bounds];
    [self.resultImageView.layer addSublayer:self.videoPreviewLayer];
    [self.captureSession startRunning];
    return YES;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputMetadataObjects:(NSArray *)metadataObjects
       fromConnection:(AVCaptureConnection *)connection {
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
        if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"%@", [metadataObj stringValue]);
                [self.showBarCodeStatus setText:[metadataObj stringValue]];
                [self stopReading];
                self.isReading = NO;
            });
        }
    }
}

- (void)stopReading {
    [self.captureSession stopRunning];
    self.captureSession = nil;
    [self.videoPreviewLayer removeFromSuperlayer];
}

#pragma mark - Animations
- (void)shakeAnimation:(UILabel*)label {
    self.showBarCodeValue.text = @"Code Copied to Clipboard";
    CABasicAnimation *shake = [CABasicAnimation animationWithKeyPath:@"position"];
    [shake setDuration:0.1];
    [shake setRepeatCount:5];
    [shake setAutoreverses:YES];
    [shake setFromValue:[NSValue valueWithCGPoint:
                         CGPointMake(label.center.x - 5,label.center.y)]];
    [shake setToValue:[NSValue valueWithCGPoint:
                       CGPointMake(label.center.x + 5, label.center.y)]];
    [label.layer addAnimation:shake forKey:@"position"];
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    [self shakeAnimation:self.showBarCodeValue];
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = self.showBarCodeStatus.text;
    
    NSString *title = @"Are you sure?";
    NSString *subTitle = nil;
    if ([self isPhoneNumber]) {
        subTitle = [NSString stringWithFormat:@"You want to call on %@", self.showBarCodeStatus.text];
    } else if (self.isLink) {
        subTitle = [NSString stringWithFormat:@"You want to open link %@", self.showBarCodeStatus.text];
    } else {
        return;
    }
    [[[UIAlertView alloc] initWithTitle:title
                                message:subTitle
                               delegate:self
                      cancelButtonTitle:@"Yes"
                      otherButtonTitles:@"No", nil] show];
    
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        NSURL *url = nil;
        if (self.isPhoneNumber) {
            NSString *urlStr = [NSString stringWithFormat:@"telprompt://%@",self.showBarCodeStatus.text];
            url = [NSURL URLWithString:urlStr];
        } else if (self.isLink) {
            url = [NSURL URLWithString:self.showBarCodeStatus.text];
        }

        if (url) {
            [[UIApplication sharedApplication] openURL:url];
        }
    }
}

- (BOOL)isLink {
    if ([self validateUrl:self.showBarCodeStatus.text]) {
        return true;
    }
    return false;
}


- (BOOL)validateUrl:(NSString *)candidate {
    NSString *urlRegEx = @"(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+";
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", urlRegEx];
    return [urlTest evaluateWithObject:candidate];
}

- (BOOL)isPhoneNumber {
    if ([self validatePhone:self.showBarCodeStatus.text]) {
        return true;
    }
    return false;
}

- (BOOL)validatePhone:(NSString *)phoneNumber {
    NSString *phoneRegex = @"^((\\+)|(00))[0-9]{6,14}$";
    NSPredicate *phoneTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", phoneRegex];
    return [phoneTest evaluateWithObject:phoneNumber];
}

@end
