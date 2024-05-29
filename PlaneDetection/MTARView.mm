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
    if (auto session = _session) {
        [session pause];
        [session release];
    }
    [_coachingOverlayView release];
    [_device release];
    [_samplerState release];
    [_renderPipelineState release];
    [_commandQueue release];
    CFRelease(_textureCacheRef);
    [super dealloc];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CAMetalLayer *metalLayer= (CAMetalLayer *)self.layer;
    CGSize size = metalLayer.bounds.size;
    CGFloat displayScale = self.traitCollection.displayScale; // TODO: Observe
    metalLayer.drawableSize = CGSizeMake(size.width * displayScale, size.height * displayScale);
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
    // TODO: https://developer.apple.com/documentation/arkit/arkit_in_ios/displaying_an_ar_experience_with_metal?language=objc
    CVPixelBufferRef capturedImage = frame.capturedImage;
    
    if (CVPixelBufferGetPlaneCount(capturedImage) < 2) {
        return;
    }
    
    ARCamera *camera = frame.camera;
    CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
    
    if (metalLayer.device == nil) {
        metalLayer.device = self.device;
    }
    
    id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
    if (drawable == nil) return;
    
    CVMetalTextureRef metalTextureYRef = NULL;
    CVReturn result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                _textureCacheRef,
                                                                capturedImage,
                                                                NULL,
                                                                MTLPixelFormatR8Unorm,
                                                                CVPixelBufferGetWidthOfPlane(capturedImage, 0),
                                                                CVPixelBufferGetHeightOfPlane(capturedImage, 0),
                                                                0,
                                                                &metalTextureYRef);
    
    if (metalTextureYRef == NULL || result != kCVReturnSuccess) {
        if (metalTextureYRef == NULL) {
            CVPixelBufferRelease(metalTextureYRef);
        }
        
        CVMetalTextureCacheFlush(_textureCacheRef, 0);
        return;
    }
    
    CVMetalTextureRef metalTextureCbCrRef = NULL;
    result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       _textureCacheRef,
                                                       capturedImage,
                                                       NULL,
                                                       MTLPixelFormatRG8Unorm,
                                                       CVPixelBufferGetWidthOfPlane(capturedImage, 1),
                                                       CVPixelBufferGetHeightOfPlane(capturedImage, 1),
                                                       1,
                                                       &metalTextureCbCrRef);
    
    if (metalTextureCbCrRef == NULL || result != kCVReturnSuccess) {
        if (metalTextureCbCrRef == NULL) {
            CVPixelBufferRelease(metalTextureCbCrRef);
        }
        
        CVMetalTextureCacheFlush(_textureCacheRef, 0);
        return;
    }
    
    id<MTLTexture> textureY = CVMetalTextureGetTexture(metalTextureYRef);
    CVPixelBufferRelease(metalTextureYRef);
    
    id<MTLTexture> textureCbCr = CVMetalTextureGetTexture(metalTextureCbCrRef);
    CVPixelBufferRelease(metalTextureCbCrRef);
    
    //
    
    float textureData[16] = {
        -1.0, -1.0,  0.0, 1.0,
        1.0, -1.0,  1.0, 1.0,
        -1.0,  1.0,  0.0, 0.0,
        1.0,  1.0,  1.0, 0.0,
    };
    
    id<MTLBuffer> textureCoordBuffer = [_device newBufferWithBytes:textureData length:sizeof(textureData) options:0];
    
    CGAffineTransform displayToCameraTransform = CGAffineTransformInvert([frame displayTransformForOrientation:UIInterfaceOrientationLandscapeRight viewportSize:metalLayer.drawableSize]);
    
    float vertexData[16] = {
        -1.0, -1.0,  0.0, 1.0,
        1.0, -1.0,  1.0, 1.0,
        -1.0,  1.0,  0.0, 0.0,
        1.0,  1.0,  1.0, 0.0,
    };
    for (NSInteger index = 0; index < 4; index++) {
        NSInteger textureCoordIndex = 4 * index + 2;
        CGPoint textureCoord = CGPointMake(textureData[textureCoordIndex], textureData[textureCoordIndex + 1]);
        CGPoint transformedCoord = CGPointApplyAffineTransform(textureCoord, displayToCameraTransform);
        vertexData[textureCoordIndex] = transformedCoord.x;
        vertexData[textureCoordIndex + 1] = transformedCoord.y;
    }
    
    id<MTLBuffer> vertexDataBuffer = [_device newBufferWithBytes:vertexData length:sizeof(vertexData) options:0];
    
    //
    
    MTLCommandBufferDescriptor *commandBufferDescriptor = [MTLCommandBufferDescriptor new];
    commandBufferDescriptor.errorOptions = MTLCommandBufferErrorOptionEncoderExecutionStatus;
    commandBufferDescriptor.retainedReferences = YES;
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBufferWithDescriptor:commandBufferDescriptor];
    [commandBufferDescriptor release];
    
    //
    
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor new];
    MTLRenderPassColorAttachmentDescriptor *firstColorAttachment = renderPassDescriptor.colorAttachments[0];
    firstColorAttachment.texture = drawable.texture;
    firstColorAttachment.loadAction = MTLLoadActionClear;
    firstColorAttachment.storeAction = MTLStoreActionStore;
    firstColorAttachment.clearColor = MTLClearColorMake(1., 1., 1., 1.);
    
    id<MTLRenderCommandEncoder> renderCommandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderPassDescriptor release];
    renderCommandEncoder.label = @"MTARView";
    [renderCommandEncoder setRenderPipelineState:_renderPipelineState];
    
    id<MTLBuffer> vertexBuffers[2] = {
        vertexDataBuffer,
        textureCoordBuffer
    };
    NSUInteger offsets[2] = {0, 0};
    
    [renderCommandEncoder setVertexBuffers:(id<MTLBuffer> *)&vertexBuffers offsets:(NSUInteger *)&offsets withRange:NSMakeRange(0, 2)];
    
    for (id<MTLBuffer> buffer : vertexBuffers) {
        [buffer release];
    }
    
    [renderCommandEncoder setFragmentTexture:textureY atIndex:0];
    [renderCommandEncoder setFragmentTexture:textureCbCr atIndex:1];
    [renderCommandEncoder setFragmentSamplerState:_samplerState atIndex:0];
    [renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [renderCommandEncoder popDebugGroup];
    [renderCommandEncoder endEncoding];
    
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

- (void)session:(ARSession *)session didAddAnchors:(NSArray<__kindof ARAnchor *> *)anchors {
    
}

- (void)session:(ARSession *)session didUpdateAnchors:(NSArray<__kindof ARAnchor *> *)anchors {
    
}


#pragma mark - ARCoachingOverlayViewDelegate

- (void)coachingOverlayViewDidRequestSessionReset:(ARCoachingOverlayView *)coachingOverlayView {
    [self start];
}

@end
