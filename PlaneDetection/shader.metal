//
//  shader.metal
//  PlaneDetection
//
//  Created by Jinwoo Kim on 5/28/24.
//

#include <metal_stdlib>
using namespace metal;

namespace pixel_buffer_shader {
    struct vertex_io {
        float4 position [[position]];
        float2 texture_coord [[user(texturecoord)]];
    };
    
    vertex vertex_io vertex_function(const device packed_float4 *positions [[buffer(0)]],
                                     const device packed_float2 *texture_coords [[buffer(1)]],
                                     uint index [[vertex_id]])
    {
        return {
            .position = positions[index],
            .texture_coord = texture_coords[index]
        };
    }
    
    fragment float4 fragment_function(vertex_io inout_fragment [[stage_in]],
                                     texture2d<float, access::sample> input_texture_y [[texture(0)]],
                                     texture2d<float, access::sample> input_texture_cbcr [[texture(1)]],
                                     sampler samplr [[sampler(0)]])
    {
//        return input_texture.sample(samplr, inout_fragment.texture_coord);
        constexpr sampler colorSampler(mip_filter::linear,
                                           mag_filter::linear,
                                           min_filter::linear);
            
            const float4x4 ycbcrToRGBTransform = float4x4(
                float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
            );
            
            // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate.
            float4 ycbcr = float4(input_texture_y.sample(colorSampler, inout_fragment.texture_coord).r,
                                  input_texture_cbcr.sample(colorSampler, inout_fragment.texture_coord).rg, 1.0);
            
            // Return the converted RGB color.
            return ycbcrToRGBTransform * ycbcr;
    }
}
