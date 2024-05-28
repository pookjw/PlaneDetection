//
//  MTARView.mm
//  PlaneDetection
//
//  Created by Jinwoo Kim on 5/28/24.
//

#import "MTARView.h"
#import <MetalKit/MetalKit.h>
#import <ARKit/ARKit.h>
#import <CoreVideo/CoreVideo.h>

__attribute__((objc_direct_members))
@interface MTARView () <ARSessionDelegate, ARCoachingOverlayViewDelegate>
@property (retain, readonly, nonatomic) ARSession *session;
@property (retain, readonly, nonatomic) ARCoachingOverlayView *coachingOverlayView;
@property (retain, readonly, nonatomic) id<MTLDevice> device;
@property (retain, readonly, nonatomic) id<MTLSamplerState> samplerState;
@property (retain, readonly, nonatomic) id<MTLRenderPipelineState> renderPipelineState;
@property (retain, readonly, nonatomic) id<MTLCommandQueue> commandQueue;
@property (assign, readonly, nonatomic) CVMetalTextureCacheRef textureCacheRef;
@end

@implementation MTARView
@synthesize session = _session;
@synthesize coachingOverlayView = _coachingOverlayView;

+ (Class)layerClass {
    return CAMetalLayer.class;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self commonInit_MTARView];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self commonInit_MTARView];
    }
    
    return self;
}

- (void)dealloc {
    [_session release];
    [_coachingOverlayView release];
    [_device release];
    [_samplerState release];
    [_renderPipelineState release];
    [_commandQueue release];
    CFRelease(_textureCacheRef);
    [super dealloc];
}

- (void)commonInit_MTARView __attribute__((objc_direct)) {
    ARCoachingOverlayView *coachingOverlayView = [ARCoachingOverlayView new];
    coachingOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:coachingOverlayView];
    [coachingOverlayView release];
    
    //
    
    NSError * _Nullable error = nil;
    
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    
    NSURL *libraryURL = [NSBundle.mainBundle URLForResource:@"default" withExtension:@"metallib"];
    id<MTLLibrary> library = [device newLibraryWithURL:libraryURL error:&error];
    assert(error == nil);
    
    //
    
    MTLFunctionDescriptor *vertexFunctionDescriptor = [MTLFunctionDescriptor new];
    vertexFunctionDescriptor.name = @"pixel_buffer_shader::vertex_function";
    
    id<MTLFunction> vertexFunction = [library newFunctionWithDescriptor:vertexFunctionDescriptor error:&error];
    assert(error == nil);
    [vertexFunctionDescriptor release];
    
    //
    
    MTLFunctionDescriptor *fragmentFunctionDescriptor = [MTLFunctionDescriptor new];
    fragmentFunctionDescriptor.name = @"pixel_buffer_shader::fragment_function";
    
    id<MTLFunction> fragmentFunction = [library newFunctionWithDescriptor:fragmentFunctionDescriptor error:&error];
    assert(error == nil);
    [fragmentFunctionDescriptor release];
    
    [library release];
    
    //
    
    MTLRenderPipelineDescriptor *renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    renderPipelineDescriptor.vertexFunction = vertexFunction;
    [vertexFunction release];
    renderPipelineDescriptor.fragmentFunction = fragmentFunction;
    [fragmentFunction release];
    
    id<MTLRenderPipelineState> renderPipelineState = [device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:&error];
    assert(error == nil);
    [renderPipelineDescriptor release];
    
    //
    
    MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    
    id<MTLSamplerState> samplerState = [device newSamplerStateWithDescriptor:samplerDescriptor];
    [samplerDescriptor release];
    
    //
    
    id<MTLCommandQueue> commandQueue = [device newCommandQueue];
    
    //
    
    CVReturn result = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, device, NULL, &_textureCacheRef);
    assert(result == kCVReturnSuccess);
    
    //
    
    _device = [device retain];
    _renderPipelineState = [renderPipelineState retain];
    _samplerState = [samplerState retain];
    _commandQueue = [commandQueue retain];
    
    [device release];
    [renderPipelineState release];
    [samplerState release];
    [commandQueue release];
}

- (ARSession *)session {
    if (auto session = _session) return session;
    
    ARSession *session = [ARSession new];
    session.delegate = self;
    
    _session = [session retain];
    return [session autorelease];
}

- (ARCoachingOverlayView *)coachingOverlayView {
    if (auto coachingOverlayView = _coachingOverlayView) return coachingOverlayView;
    
    ARCoachingOverlayView *coachingOverlayView = [ARCoachingOverlayView new];
    
    coachingOverlayView.delegate = self;
    coachingOverlayView.goal = ARCoachingGoalAnyPlane;
    coachingOverlayView.session = self.session;
    
    _coachingOverlayView = [coachingOverlayView retain];
    return [coachingOverlayView autorelease];
}

- (ARWorldTrackingConfiguration *)makeConfiguration __attribute__((objc_direct)) {
    ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfiguration new];
    configuration.planeDetection = ARPlaneDetectionHorizontal | ARPlaneDetectionVertical;
    
    return [configuration autorelease];
}

- (void)start {
    [self.session runWithConfiguration:[self makeConfiguration]];
}

- (void)pause {
    [self.session pause];
}


#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    CVPixelBufferRef capturedImage = frame.capturedImage;
    ARCamera *camera = frame.camera;
    CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
    
    id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
    if (drawable == nil) return;

    
    CVMetalTextureRef metalTextureRef = NULL;
    CVReturn result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                _textureCacheRef,
                                                                capturedImage,
                                                                NULL,
                                                                MTLPixelFormatBGRA8Unorm,
                                                                width,
                                                                height,
                                                                0,
                                                                &metalTextureRef);
    
    if (metalTextureRef == NULL || result != kCVReturnSuccess) {
        if (metalTextureRef == NULL) {
            CVPixelBufferRelease(metalTextureRef);
        }
        
        CVMetalTextureCacheFlush(_textureCacheRef, 0);
        return;
    }
    
    id<MTLTexture> texture = CVMetalTextureGetTexture(metalTextureRef);
    CVPixelBufferRelease(metalTextureRef);
    
    //
    
    CGSize drawableSize = metalLayer.drawableSize;
    size_t width = CVPixelBufferGetWidth(capturedImage);
    size_t height = CVPixelBufferGetHeight(capturedImage);
    
    // texture를 drawableSize에 맞게 Aspect Fill
    float scaleX;
    float scaleY;
    /*
     1. 아래처럼 Captured Image가 있다고 가정하자
     +-----------------+
     |     Captured    | 600x300
     |       Image     |
     |                 |
     +-----------------+
     
     2. 우선 정사각형 안에서 Aspect Fill하게 Rendering 해야 한다면 아래처럼 Scale을 곱해줘야 한다.
     Scale X (1) = 1.0
     Scale Y (1) = (Height / Width) = 2.0
     
     3. 그 정사각형을 아래 사각형 안에서 Aspect Fill 하게 보여야 한다면 아래처럼 Scale을 곱해줘야 한다.
     Scale X (2) = Scale X (1) * (Height / Width) = 1.5
     Scale Y (2) = Scale Y (1) = 2.0
     
     +------+
     |      |
     |      |
     |      |
     | Metal| 800x1200
     | Layer|
     |      |
     |      |
     +------+
     */
    if (width < height) {
        scaleX = 1.f;
        scaleY = (height / width);
    } else {
        scaleX = (width / height);
        scaleY = 1.f;
    }
    
    if (drawableSize.width < drawableSize.height) {
        scaleX *= (drawableSize.height / drawableSize.width);
    } else {
        scaleY *= (drawableSize.width / drawableSize.height);
    }
}

- (void)session:(ARSession *)session didAddAnchors:(NSArray<__kindof ARAnchor *> *)anchors {
    NSLog(@"%@", anchors);
}

- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<__kindof ARAnchor *> *)anchors {
    
}


#pragma mark - ARCoachingOverlayViewDelegate

- (void)coachingOverlayViewDidRequestSessionReset:(ARCoachingOverlayView *)coachingOverlayView {
    [self start];
}

@end
