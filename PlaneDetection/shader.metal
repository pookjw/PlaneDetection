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
    
    fragment half4 fragment_function(vertex_io inout_fragment [[stage_in]],
                                     texture2d<half> input_texture [[texture(0)]],
                                     sampler samplr [[sampler(0)]])
    {
        return input_texture.sample(samplr, inout_fragment.texture_coord);
    }
    
//    struct VertexIO {
//        float4 position [[position]];
//        float2 textureCoord [[user(texturecoord)]];
//    };
//    
//    vertex VertexIO vertexFunction(const device packed_float4 *positions [[buffer(0)]],
//                                   const device packed_float2 *textrueCoords [[buffer(1)]],
//                                   uint vertexID [[vertex_id]])
//    {
//        return {
//            .position = positions[vertexID],
//            .textureCoord = textrueCoords[vertexID]
//        };
//    }
//    
//    fragment half4 fragmentFunction(VertexIO inoutFragment [[stage_in]],
//                                    texture2d<half> inputTexture [[texture(0)]],
//                                    sampler samplr [[sampler(0)]])
//    {
//        return inputTexture.sample(samplr, inoutFragment.textureCoord);
//    }
}
