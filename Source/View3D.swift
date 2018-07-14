import UIKit
import Metal

let NUMNODE:Int = Int(SIZE3D * SIZE3D)

var height:Float = 10
var vBuffer: MTLBuffer?
var vBuffer2: MTLBuffer?

class View3D {
    var iBufferT: MTLBuffer?
    var vData = Array(repeating:TVertex(), count:NUMNODE)
    var iDataT = Array<UInt16>()
    let vSize:Int = MemoryLayout<TVertex>.stride * NUMNODE
    
    func initialize() {
        let fSize = Float(SIZE3D)

        var index:Int = 0
        for z in 0 ..< SIZE3D {
            for x in 0 ..< SIZE3D {
                var v = TVertex()
                v.pos.x = Float(x - SIZE3D/2)
                v.pos.y = Float(0)
                v.pos.z = Float(z - SIZE3D/2)
                
                v.nrm = normalize(v.pos)
                
                v.txt.x = Float(x) / fSize
                v.txt.y = Float(1) - Float(z) / fSize
                v.color = float4( Float(z) / fSize, Float(x) / fSize,1,1)
                
                vData[index] = v
                index += 1
            }
        }
        
        for y in 0 ..< SIZE3Dm {
            for x in 0 ..< SIZE3Dm {
                let p1 = UInt16(x + y * SIZE3D)
                let p2 = UInt16(x + 1 + y * SIZE3D)
                let p3 = UInt16(x + (y+1) * SIZE3D)
                let p4 = UInt16(x + 1 + (y+1) * SIZE3D)
                
                iDataT.append(p1)
                iDataT.append(p3)
                iDataT.append(p2)
                
                iDataT.append(p2)
                iDataT.append(p3)
                iDataT.append(p4)
            }
        }
        
        vBuffer  = gDevice?.makeBuffer(bytes: vData,  length: vSize, options: MTLResourceOptions())
        vBuffer2 = gDevice?.makeBuffer(bytes: vData,  length: vSize, options: MTLResourceOptions())
        iBufferT = gDevice?.makeBuffer(bytes: iDataT, length: iDataT.count * MemoryLayout<UInt16>.size,  options: MTLResourceOptions())
    }
    
    func render(_ renderEncoder:MTLRenderCommandEncoder) {
        if vData.count > 0 {
            renderEncoder.setVertexBuffer(vBuffer, offset: 0, index: 0)
            renderEncoder.drawIndexedPrimitives(type: .triangle,  indexCount: iDataT.count, indexType: MTLIndexType.uint16, indexBuffer: iBufferT!, indexBufferOffset:0)
        }
    }
}

