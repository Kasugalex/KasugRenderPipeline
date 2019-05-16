#ifndef MYRP_LIT_INCLUDED
#define MYRP_LIT_INCLUDED

/*cbuffer UnityPerFrame {
	float4x4 unity_MatrixVP;
};
cbuffer UnityPerDraw {
	float4x4 unity_ObjectToWorld;
};*/

//use Common.hlsl to make CBUFFER_START correct
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
//#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

#define MAX_VISIBLE_LIGHTS 16

//cbuffer don't benefit all platforms,so I use macros(宏)
CBUFFER_START(UnityPerFrame)
float4x4 unity_MatrixVP;
CBUFFER_END

CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;
//Light Indices
//The indices are made available via the unity_4LightIndices0 and unity_4LightIndices1 vectors, which should be part of the UnityPerDraw buffer.
float4 unity_LightIndicesOffsetAndCount;
float4 unity_4LightIndices0, unity_4LightIndices1;
CBUFFER_END

CBUFFER_START(_LightBuffer)
float4 _VisibleLightColors[MAX_VISIBLE_LIGHTS];
float4 _VisibleLightDirectionsOrPositions[MAX_VISIBLE_LIGHTS];
float4 _VisibleLightAttenuations[MAX_VISIBLE_LIGHTS];
float4 _VisibleLightSpotDirections[MAX_VISIBLE_LIGHTS];
CBUFFER_END

CBUFFER_START(_ShadowBuffer)
float4x4 _WorldToShadowMatrix;
CBUFFER_END

//Use this macro to define shadowMap
TEXTURE2D_SHADOW(_ShadowMap);
//define the sampler for sampling the texture
SAMPLER_CMP(sampler_ShadowMap);

float ShadowAttenuation(float3 worldPos) {
	float4 shadowPos = mul(_WorldToShadowMatrix, float4(worldPos, 1.0));
	//here need the regular coordinates,so devide XYZ by its W
	shadowPos.xyz /= shadowPos.w;
	return SAMPLE_TEXTURE2D_SHADOW(_ShadowMap, sampler_ShadowMap, shadowPos.xyz);
}


float3 DiffuseLight(int index, float3 normal, float3 worldPos,float shadowAttenuation) {
	float3 lightColor = _VisibleLightColors[index].rgb;
	float4 lightPositionOrDirection = _VisibleLightDirectionsOrPositions[index];
	float4 lightAttenuation = _VisibleLightAttenuations[index];
	float3 spotDirection = _VisibleLightSpotDirections[index].xyz;
	//lightPositionOrDirection.w -- 1 is position and 0 is direction
	float3 lightVector = lightPositionOrDirection.xyz - worldPos * lightPositionOrDirection.w;
	float3 lightDirection = normalize(lightVector);
	float diffuse = saturate(dot(normal, lightDirection));
	float lightIndensitySqr = dot(lightVector, lightVector);
	//Light Attenuation
	float rangeFade = lightIndensitySqr * lightAttenuation.x;
	rangeFade = saturate(1.0 - rangeFade * rangeFade);
	rangeFade *= rangeFade;
	//Spot light
	float spotFade = dot(spotDirection, lightDirection);
	spotFade = saturate(spotFade * lightAttenuation.z + lightAttenuation.w);
	spotFade *= spotFade;

	//Distance Attenuation--  this relation is i / d^2  (i is the light's intensity ,d is distance)
	float distanceSqr = max(lightIndensitySqr, 0.00001);
	diffuse *= shadowAttenuation * spotFade *  rangeFade / distanceSqr;
	return diffuse * lightColor;
}

/* normal Color
CBUFFER_START(UnityPerMaterial)
float4 _Color;
CBUFFER_END
*/

#define UNITY_MATRIX_M unity_ObjectToWorld

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
//Instance Color
UNITY_INSTANCING_BUFFER_START(PerInstance)
UNITY_DEFINE_INSTANCED_PROP(float4,_Color)
UNITY_INSTANCING_BUFFER_END(PerInstance)


struct VertexInput {
	float4 pos : POSITION;
	float3 normal:NORMAL;
	//UNITY_MATRIX_M relies on the index,so add it to the VertexInput.
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput {
	float4 clipPos :SV_POSITION;
	float3 normal:NORMAL;
	float3 worldPos:TEXCOORD1;
	float3 vertexLighting:TEXCOORD2;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};


VertexOutput LitPassVertex(VertexInput input) {
	VertexOutput output;
	//should make the index avaliable before using UNITY_MATRIX_M
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_TRANSFER_INSTANCE_ID(input,output);
	float4 worldPos = mul(UNITY_MATRIX_M, float4(input.pos.xyz, 1.0));
	output.clipPos = mul(unity_MatrixVP, worldPos);
	output.normal = mul((float3x3)UNITY_MATRIX_M,input.normal);
	output.worldPos = worldPos.xyz;

	output.vertexLighting = 0;
	for (int i = 4; i < min(8, unity_LightIndicesOffsetAndCount.y); i++)
	{
		int lightIndex = unity_4LightIndices1[i - 4];
		output.vertexLighting += DiffuseLight(lightIndex, output.normal, output.worldPos,1);
	}
	return output;
}

float4 LitPassFragment(VertexOutput input) : SV_Target{
	UNITY_SETUP_INSTANCE_ID(input);
	input.normal = normalize(input.normal);
	float3 albedo = UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Color).rgb;

	float3 diffuseLight = input.vertexLighting;
	// Its Y component contains the number of lights affecting the object
	for (int i = 0; i < min(4, unity_LightIndicesOffsetAndCount.y); i++)
	{
		int lightIndex = unity_4LightIndices0[i];
		float shadowAttenuation = ShadowAttenuation(input.worldPos);
		diffuseLight += DiffuseLight(lightIndex, input.normal, input.worldPos, shadowAttenuation);
	}

	//float3 diffuseLight = saturate(dot(input.normal,float3(0,1,0)));
	//float3 diffuseLight = 0.5 * dot(input.normal,float3(-1,1,0)) + 0.5;
	float3 color = diffuseLight * albedo;
	return float4(color, 1);
}

#endif

