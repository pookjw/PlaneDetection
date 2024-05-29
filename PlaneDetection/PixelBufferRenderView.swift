//
//  PixelBufferRenderView.swift
//  Booth
//
//  Created by Jinwoo Kim on 9/24/23.
//

import UIKit
import MetalKit
import AVFoundation

@MainActor
final class PixelBufferRenderView: UIView {
    @objc var pixelBuffer: CVPixelBuffer? {
        didSet {
            render()
        }
    }
//    var captureOrientation: (AVCaptureVideoOrientation, AVCaptureDevice.Position) {
//        didSet {
//            render()
//        }
//    }
    private let renderer: Renderer = .init()
    private var interfaceOrientationRegistration: NSObjectProtocol?
    private var metalLayer: CAMetalLayer { layer as! CAMetalLayer }
    
    override class var layerClass: AnyClass {
        CAMetalLayer.self
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
//        if let windowScene: UIWindowScene = window?.windowScene {
//            interfaceOrientationRegistration = NotificationCenter.default.addObserver(forName: .UIWindowSceneInterfaceOrientationDidChange, object: windowScene, queue: nil) { [weak self] notification in
//                Task { @MainActor [weak self] in
//                    self?.render()
//                }
//            }
//        } else {
//            interfaceOrientationRegistration = nil
//        }
    }
    
    private func render() {
        Task { [renderer, pixelBuffer, metalLayer] in
            guard let pixelBuffer: CVPixelBuffer else { return }
            metalLayer.drawableSize = bounds.size
            await renderer.draw(pixelBuffer: pixelBuffer, in: metalLayer)
        }
    }
}

extension PixelBufferRenderView {
    fileprivate actor Renderer {
        private var didSetup: Bool = false
        private var device: MTLDevice!
        private var sampler: MTLSamplerState!
        private var renderPipelineState: MTLRenderPipelineState!
        private var commandQueue: MTLCommandQueue!
        private var textureCache: CVMetalTextureCache!
        
        func draw(pixelBuffer: CVPixelBuffer, in metalLayer: CAMetalLayer) async {
            try! configureIfNeeded()
            
            if metalLayer.device == nil {
                metalLayer.device = device
            }
            
            guard let drawable: CAMetalDrawable = metalLayer.nextDrawable() else {
                print("Too many requests... \(metalLayer.drawableSize)")
                return
            }
            
            // MARK: - Get Textures
            
            let width: Int = CVPixelBufferGetWidth(pixelBuffer)
            let height: Int = CVPixelBufferGetHeight(pixelBuffer)
            
            var _metalTexture: CVMetalTexture?
            CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                pixelBuffer,
                nil,
                .bgra8Unorm,
                width,
                height,
                .zero,
                &_metalTexture
            )
            
            guard
                let metalTexture: CVMetalTexture = _metalTexture,
                let texture: MTLTexture = CVMetalTextureGetTexture(metalTexture)
            else {
                CVMetalTextureCacheFlush(textureCache, .zero)
                return
            }
            
            // MARK: - Get Buffers
            
            let drawableSize: CGSize = drawable.layer.drawableSize
            var scaleX: Float
            var scaleY: Float
            if width < height {
                scaleX = 1.0
                scaleY = Float(height) / Float(width)
            } else {
                scaleX = Float(width) / Float(height)
                scaleY = 1.0
            }
            
            if drawableSize.width < drawableSize.height {
                scaleX *= Float(drawableSize.height / drawableSize.width)
            } else {
                scaleY *= Float(drawableSize.width / drawableSize.height)
            }
            
            let vertexData: [Float] = [
                -scaleX, -scaleY, 0.0, 1.0,
                scaleX, -scaleY, 0.0, 1.0,
                -scaleX, scaleY, 0.0, 1.0,
                scaleX, scaleY, 0.0, 1.0
            ]
            let vertexCoordBuffer: MTLBuffer = device.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: .init())!
            
            let textureData: [Float] = [
                .zero, 1.0,
                1.0, 1.0,
                .zero, .zero,
                1.0, .zero
            ]
            let textureCorrdBuffer: MTLBuffer = device.makeBuffer(bytes: textureData, length: textureData.count * MemoryLayout<Float>.size, options: .init())!
            
            //
            
            let commandBufferDescriptor: MTLCommandBufferDescriptor = .init()
            let commandBuffer: MTLCommandBuffer = commandQueue.makeCommandBuffer(descriptor: commandBufferDescriptor)!
            
            //
            
            let renderPassDescriptor: MTLRenderPassDescriptor = .init()
            renderPassDescriptor.colorAttachments[.zero].texture = drawable.texture
            renderPassDescriptor.colorAttachments[.zero].loadAction = .clear
            renderPassDescriptor.colorAttachments[.zero].storeAction = .store
            renderPassDescriptor.colorAttachments[.zero].clearColor = .init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            
            let commandEncoder: MTLRenderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            commandEncoder.label = String(describing: self)
            commandEncoder.setRenderPipelineState(renderPipelineState)
            commandEncoder.setVertexBuffer(vertexCoordBuffer, offset: .zero, index: .zero)
            commandEncoder.setVertexBuffer(textureCorrdBuffer, offset: .zero, index: 1)
            commandEncoder.setFragmentTexture(texture, index: .zero)
            commandEncoder.setFragmentSamplerState(sampler, index: .zero)
            commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: .zero, vertexCount: 4)
            commandEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        private func configureIfNeeded() throws {
            guard !didSetup else { return }
            defer { didSetup = true }
            
            let device: MTLDevice = MTLCreateSystemDefaultDevice()!
            let library: MTLLibrary = try device.makeDefaultLibrary(bundle: .init(for: PixelBufferRenderView.self))
            
            let vertexFunction: MTLFunctionDescriptor = .init()
            vertexFunction.name = "pixel_buffer_shader::vertexFunction"
            
            let fragmentFunction: MTLFunctionDescriptor = .init()
            fragmentFunction.name = "pixel_buffer_shader::fragmentFunction"
            
            let pipelineDescriptor: MTLRenderPipelineDescriptor = .init()
            pipelineDescriptor.colorAttachments[.zero].pixelFormat = .bgra8Unorm
            pipelineDescriptor.vertexFunction = try library.makeFunction(descriptor: vertexFunction)
            pipelineDescriptor.fragmentFunction = try library.makeFunction(descriptor: fragmentFunction)
            let renderPipelineState: MTLRenderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            let samplerDescriptor: MTLSamplerDescriptor = .init()
            samplerDescriptor.sAddressMode = .clampToEdge
            samplerDescriptor.tAddressMode = .clampToEdge
            samplerDescriptor.minFilter = .linear
            samplerDescriptor.magFilter = .linear
            let sampler: MTLSamplerState = device.makeSamplerState(descriptor: samplerDescriptor)!
            
            let commandQueue: MTLCommandQueue = device.makeCommandQueue()!
            
            var _textureCache: CVMetalTextureCache?
            let result: CVReturn = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &_textureCache)
            assert(result == kCVReturnSuccess)
            let textureCache: CVMetalTextureCache = _textureCache!
            
            //
            
            self.device = device
            self.sampler = sampler
            self.renderPipelineState = renderPipelineState
            self.sampler = sampler
            self.commandQueue = commandQueue
            self.textureCache = textureCache
        }
    }
}
