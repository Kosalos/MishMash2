import UIKit
import Metal
import MetalKit

class MetalTextureView: MTKView,MTKViewDelegate {
    var pipelineR: MTLRenderPipelineState!
    var sampler: MTLSamplerState?
    var vertices: MTLBuffer?
    var outTexture: MTLTexture! = nil
    let queue = DispatchQueue(label:"Q")
    var commandQueue: MTLCommandQueue! = nil
    
    func initialize(_ texture:MTLTexture) {
        delegate = self
        outTexture = texture
        
        if commandQueue == nil {
            let device:MTLDevice! = MTLCreateSystemDefaultDevice()
            self.device = device
            commandQueue = device.makeCommandQueue()
            
            do {
                let library: MTLLibrary = try device.makeDefaultLibrary(bundle: .main)
                let descriptor: MTLRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction   = library.makeFunction(name: "metalTextureView_Vertex")
                descriptor.fragmentFunction = library.makeFunction(name: "metalTextureView_Fragment")
                descriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
                pipelineR = try device.makeRenderPipelineState(descriptor: descriptor)
            } catch {
                fatalError(String(describing: error))
            }
            
            let p1 = simd_float2(0,0)
            let p2 = simd_float2(1,0)
            let p3 = simd_float2(0,1)
            let p4 = simd_float2(1,1)
            vertices = device.makeBuffer(bytes: [p1,p2,p3,p4], length: 4 * MemoryLayout<simd_float2>.stride,  options: [])
            
            let descriptor: MTLSamplerDescriptor = MTLSamplerDescriptor()
            descriptor.magFilter = .nearest
            descriptor.minFilter = .nearest
            descriptor.sAddressMode = .repeat
            descriptor.tAddressMode = .repeat
            sampler = device.makeSamplerState(descriptor: descriptor)
            
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinch(_:)))
            addGestureRecognizer(pinch)
        }
    }
    
    @IBAction func handlePinch(_ sender: UIPinchGestureRecognizer) {
        vc.alterZoomViaPinch(Float(sender.scale))
    }
    
    //MARK: -
    
    func draw(in view: MTKView) {
        if outTexture == nil { Swift.print("Must call MetalTextureView.initialize() first!"); exit(0) }
        
        let descriptor:MTLRenderPassDescriptor = currentRenderPassDescriptor!
        let commandBuffer = commandQueue.makeCommandBuffer()!
        guard let encoder: MTLRenderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        encoder.setRenderPipelineState(pipelineR)
        encoder.setVertexBuffer(vertices, offset: 0, index: 0)
        encoder.setFragmentTexture(outTexture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        if let drawable = currentDrawable { commandBuffer.present(drawable) }
        commandBuffer.commit()
    }
    
    //MARK: -
    
    var pt = CGPoint()
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            pt = touch.location(in: self)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            var npt = touch.location(in: self)
            npt.x -= pt.x
            npt.y -= pt.y
            vc.focusMovement(npt)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchesEnded(touches, with:event) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        pt.x = 0
        pt.y = 0
        vc.focusMovement(pt)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
}
