#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

using namespace metal;

struct Transfer {
    float4 position [[position]];
    float4 lighting;
    float4 color;
};

vertex Transfer texturedVertexShader
(
 device TVertex* vData [[ buffer(0) ]],
 constant ConstantData& constantData [[ buffer(1) ]],
 unsigned int vid [[ vertex_id ]])
{
    Transfer out;
    TVertex v = vData[vid];
    
    out.color = v.color;
    out.position = constantData.mvp * float4(v.pos, 1.0);
    
    float intensity = 0.2 + saturate(dot(vData[vid].nrm.rgb, constantData.light.xyz));
    out.lighting = float4(intensity,intensity,intensity,1);
    
    return out;
}

fragment float4 texturedFragmentShader
(
 Transfer data [[stage_in]])
{
    return data.color * data.lighting;
}

/////////////////////////////////////////////////////////////////////////

kernel void heightMapShader
(
 texture2d<float, access::read> srcTexture [[texture(0)]],
 device TVertex* vData      [[ buffer(0) ]],
 constant Control &control  [[ buffer(1) ]],
 uint2 p [[thread_position_in_grid]])
{
    if(p.x > SIZE3Dm || p.y > SIZE3Dm) return; // threadCount mismatch
    
    int2 pp = int2(p);   // centered on source pixels
    int size = SIZE3D;
    switch(control.zoom) {
        case 0 :  // zoom in
            pp.x /= 2;
            pp.y /= 2;
            size /= 2;
            break;
        case 2 :  // zoom out
            pp.x *= 2;
            pp.y *= 2;
            size *= 2;
            break;
    }
    
    pp.x += (control.xSize - size) / 2;
    pp.y += (control.ySize - size) / 2;
    
    float4 c = srcTexture.read(uint2(pp));
    float height = (c.x + c.y + c.z) * control.height / 3.0;
    
    int index = int(SIZE3D - 1 - p.y) * SIZE3D + int(p.x);
    vData[index].pos.y = height;
    vData[index].color = c;
}

/////////////////////////////////////////////////////////////////////////

kernel void smoothingShader
(
 constant TVertex* src      [[ buffer(0) ]],
 device TVertex* dst        [[ buffer(1) ]],
 uint2 p [[thread_position_in_grid]])
{
    if(p.x > SIZE3Dm || p.y > SIZE3Dm) return; // threadCount mismatch
    
    int index = int(p.y) * SIZE3D + int(p.x);
    
    if(p.x == 0) p.x = 1; else if(p.x > SIZE3D-2) p.x = SIZE3D-3;
    if(p.y == 0) p.y = 1; else if(p.y > SIZE3D-2) p.y = SIZE3D-3;
    int vIndex = int(p.y) * SIZE3D + int(p.x);

    TVertex v = src[vIndex];
    
    for(int x = -1; x <= 1; ++x) {
        for(int y = -1; y <= 1; ++y) {
            if(y == 0) continue;
            
            int index2 = vIndex + y * SIZE3D + x;
            v.pos.y += src[index2].pos.y;
            v.color += src[index2].color;
        }
    }
    
    v.pos.y /= 7;
    v.color /= 7;
    
    dst[index] = v;
}

/////////////////////////////////////////////////////////////////////////

kernel void normalShader
(
 device TVertex* v [[ buffer(0) ]],
 uint2 p [[thread_position_in_grid]])
{
    if(p.x > SIZE3Dm || p.y > SIZE3Dm) return; // threadCount mismatch
    
    int i = int(p.y) * SIZE3D + int(p.x);
    int i2 = i + ((p.x < SIZE3Dm) ? 1 : -1);
    int i3 = i + ((p.y < SIZE3Dm) ? SIZE3D : -SIZE3D);
    
    TVertex v1 = v[i];
    TVertex v2 = v[i2];
    TVertex v3 = v[i3];
    
    v[i].nrm = normalize(cross(v1.pos - v2.pos, v1.pos - v3.pos));
}
