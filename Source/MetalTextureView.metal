#include <metal_stdlib>
using namespace metal;

struct Attribute {
    float4 position [[ position ]];
    float2 texcoord [[ user(tx) ]];
    inline Attribute(thread float2 const arg) {
        float2 t = fma(-2, arg, 1);
        position = float4(-t.x,t.y, 0, 1);
        texcoord = arg;
    };
};

vertex Attribute metalTextureView_Vertex
(
 constant float2 * const vertices [[ buffer(0) ]],
 uint const idx [[ vertex_id ]])
{
    return Attribute(vertices[idx]);
}

fragment float4 metalTextureView_Fragment
(
 Attribute const attribute [[ stage_in ]],
 texture2d<float, access::sample> texture [[ texture(0) ]],
 sampler const sampler [[ sampler(0) ]])
{
    return texture.sample(sampler, attribute.texcoord);
}
