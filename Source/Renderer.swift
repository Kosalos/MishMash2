import Metal
import MetalKit
import simd

let maxBuffersInFlight = 3

enum RendererError: Error {
    case badVertexDescriptor
}

var gDevice:MTLDevice!
var mtlVertexDescriptor:MTLVertexDescriptor!

var constants: [MTLBuffer] = []
var constantsSize: Int = MemoryLayout<ConstantData>.stride
var constantsIndex: Int = 0
let kInFlightCommandBuffers = 3
var translation = simd_float3(0,0,40)
var lightpos:simd_float3 = simd_float3()
var lAngle:Float = 0

class Renderer: NSObject, MTKViewDelegate {
    var ident:Int = 0
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    //var texture: MTLTexture! = nil
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    var samplerState:MTLSamplerState!

    var projectionMatrix: matrix_float4x4 = matrix_float4x4()

    init?(metalKitView: MTKView, _ mIdent:Int) {
        ident = mIdent
        gDevice = metalKitView.device!
        self.commandQueue = gDevice.makeCommandQueue()!
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm
        metalKitView.sampleCount = 1
        
        mtlVertexDescriptor = Renderer.buildMetalVertexDescriptor()
        
        do { pipelineState = try Renderer.buildRenderPipelineWithDevice(device: gDevice,  metalKitView: metalKitView,  mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {  print("Unable to compile render pipeline state.  Error info: \(error)"); exit(0) }
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        depthState = gDevice.makeDepthStencilState(descriptor:depthStateDesciptor)!

        // texture
//        let sampler = MTLSamplerDescriptor()
//        sampler.minFilter             = MTLSamplerMinMagFilter.nearest
//        sampler.magFilter             = MTLSamplerMinMagFilter.nearest
//        sampler.mipFilter             = MTLSamplerMipFilter.nearest
//        sampler.maxAnisotropy         = 1
//        sampler.sAddressMode          = MTLSamplerAddressMode.repeat
//        sampler.tAddressMode          = MTLSamplerAddressMode.repeat
//        sampler.rAddressMode          = MTLSamplerAddressMode.repeat
//        sampler.normalizedCoordinates = true
//        sampler.lodMinClamp           = 0
//        sampler.lodMaxClamp           = .greatestFiniteMagnitude
//        samplerState = gDevice.makeSamplerState(descriptor: sampler)
//
//        do { texture = try Renderer.loadTexture(device: gDevice, textureName: "copper")
//        } catch { print("Unable to load texture. Error info: \(error)");  exit(0)  }
        
        constants = []
        for _ in 0..<kInFlightCommandBuffers {
            constants.append(gDevice.makeBuffer(length: constantsSize, options: [])!)
        }
        
        super.init()
    }
    
    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        let mtlVertexDescriptor = MTLVertexDescriptor()
 
        mtlVertexDescriptor.attributes[0].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[0].offset = 0
        mtlVertexDescriptor.attributes[0].bufferIndex = 0
        
        mtlVertexDescriptor.attributes[1].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[1].offset = 0
        mtlVertexDescriptor.attributes[1].bufferIndex = 1
        
        mtlVertexDescriptor.layouts[0].stride = 12
        mtlVertexDescriptor.layouts[0].stepRate = 1
        mtlVertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
        
        mtlVertexDescriptor.layouts[1].stride = 8
        mtlVertexDescriptor.layouts[1].stepRate = 1
        mtlVertexDescriptor.layouts[1].stepFunction = MTLVertexStepFunction.perVertex

        return mtlVertexDescriptor
    }
    
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        let library = device.makeDefaultLibrary()
        
        let vFunction = library?.makeFunction(name: "texturedVertexShader")
        let fFunction = library?.makeFunction(name: "texturedFragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vFunction
        pipelineDescriptor.fragmentFunction = fFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    class func loadTexture(device: MTLDevice, textureName: String) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)
        return try textureLoader.newTexture(name: textureName, scaleFactor: 1.0, bundle: nil,  options: nil)
    }
    
    var pace:Int = 0
    var lightpos:simd_float3 = simd_float3()
    var lAngle:Float = 0

    func draw(in view: MTKView) {
        
        if !is3D { return }
        pace += 1
        if pace < 3 { return }
        pace = 0
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        let semaphore = inFlightSemaphore
        commandBuffer?.addCompletedHandler { (_ commandBuffer)-> Swift.Void in semaphore.signal() }
      
        let renderPassDescriptor = view.currentRenderPassDescriptor
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
        renderEncoder?.setCullMode(.none) // .back)
        renderEncoder?.setFrontFacing(.clockwise)
        renderEncoder?.setRenderPipelineState(pipelineState)
        renderEncoder?.setDepthStencilState(depthState)
        renderEncoder?.setFragmentSamplerState(samplerState, index: 0)

        let parallax:Float = -0.02195
        let stereoAngle:Float = ident == 0 ? -parallax : +parallax
        
        // -----------------------------
        let constant_buffer = constants[constantsIndex].contents().assumingMemoryBound(to: ConstantData.self)
        constant_buffer[0].mvp =
            projectionMatrix
            * translate(0,0,translation.z)
            * rotate(stereoAngle*100,simd_float3(0,1,0))
            * arcBall.transformMatrix

        if ident == 0 {
            lightpos.x = sinf(lAngle)
            lightpos.y = 1
            lightpos.z = cosf(lAngle)
            lAngle += 0.012
            constant_buffer[0].light = normalize(lightpos)
        }
        
        renderEncoder?.setVertexBuffer(constants[constantsIndex], offset:0, index: 1)

        // ----------------------------------------------
        view3D.render(renderEncoder!)
        // ----------------------------------------------

        renderEncoder?.endEncoding()
        
        if let drawable = view.currentDrawable { commandBuffer?.present(drawable)  }
        commandBuffer?.commit()
        constantsIndex = (constantsIndex + 1) % kInFlightCommandBuffers
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let aspect = Float(size.width) / Float(size.height)
        let kFOVY: Float = 65.0
        projectionMatrix = perspective_fov(kFOVY, aspect, 0.1, 1000.0)
    }
}
