#pragma once
#include "MishMash.h"

struct TVertex {
    vector_float3 pos;
    vector_float3 nrm;
    vector_float2 txt;
    vector_float4 color;
};

struct ConstantData {
    matrix_float4x4 mvp;
    vector_float3 light;
};
