#ifndef MYRP_SHADOWCASTER_INCLUDED
#define MYRP_SHADOWCASTER_INCLUDED

//use Common.hlsl to make CBUFFER_START correct
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

#define UNITY_MATRIX_M unity_ObjectToWorld

//cbuffer don't benefit all platforms,so I use macros(宏)
CBUFFER_START(UnityPerFrame)
float4x4 unity_MatrixVP;
CBUFFER_END

CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
CBUFFER_END

struct VertexInput {
	float4 pos : POSITION;
	//UNITY_MATRIX_M relies on the index,so add it to the VertexInput.
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput {
	float4 clipPos :SV_POSITION;
};


VertexOutput ShadowCasterPassVertex(VertexInput input) {
	VertexOutput output;
	UNITY_SETUP_INSTANCE_ID(input);
	//should make the index avaliable before using UNITY_MATRIX_M
	float4 worldPos = mul(UNITY_MATRIX_M, float4(input.pos.xyz, 1.0));
	output.clipPos = mul(unity_MatrixVP, worldPos);
	//shadow casters may intersect the near plane,to prevent this,should clamp the vertices to near place
	//OpenGL the  near plane value is -1
#if UNITY_REVERSED_Z
	output.clipPos.z = min(output.clipPos.z,output.clipPos.w * UNITY_NEAR_CLIP_VALUE);

#else
	output.clipPos.z = max(output.clipPos.z, output.clipPos.w * UNITY_NEAR_CLIP_VALUE);
#endif
	return output;
}

float4 ShadowCasterPassFragment(VertexOutput input) : SV_Target{
	return float4(0, 0, 0, 0);
}

#endif

