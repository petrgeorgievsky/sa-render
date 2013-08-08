float4x4 gmWorldViewProj;
float4x4 gmWorld;
float4x4 gmWorldView;
float4x4 TexTransform;
float4x4 gmLightViewProj;
float4x4 gmLightViewProj2;
float4 gvDirLight;
float4 gvPaintColor = float4(1,1,1,1);
float4 gvAmbientColor;
float4 gvAmbientColor2;
float4 gvEye;
texture2D shadowTex;
texture2D shadowTex2;
texture2D gtDiffuse;
texture2D gtNormals;
texture2D gtSpecular;
float screenHeight;
float screenWidth;
sampler2D shadowSampler = sampler_state
{
   Texture = <shadowTex>;
	MinFilter = LINEAR;  
    MagFilter = LINEAR;
    MipFilter = None;
    AddressU = Border;
	AddressV = Border;
	AddressW = Border;
	BorderColor = 0xFFFFFF;
};
sampler2D shadowSampler2 = sampler_state
{
   Texture = <shadowTex2>;
	MinFilter = LINEAR;  
    MagFilter = LINEAR;
    MipFilter = None;
    AddressU  = Clamp;
    AddressV  = Clamp;
};
sampler2D gsDiffuse = sampler_state
{
   Texture = <gtDiffuse>;
	MinFilter = ANISOTROPIC;  
    MagFilter = ANISOTROPIC;
    MipFilter = ANISOTROPIC;
    AddressU  = Wrap;
    AddressV  = Wrap;
};
sampler2D gsNormals = sampler_state
{
   Texture = <gtNormals>;
	MinFilter = ANISOTROPIC;  
    MagFilter = ANISOTROPIC;
    MipFilter = ANISOTROPIC;
    AddressU  = Wrap;
    AddressV  = Wrap;
};
sampler2D gsSpecular = sampler_state
{
   Texture = <gtSpecular>;
	MinFilter = ANISOTROPIC;  
    MagFilter = ANISOTROPIC;
    MipFilter = ANISOTROPIC;
    AddressU  = Wrap;
    AddressV  = Wrap;
};
struct VS_OUTPUT
{
    float4 vpos     : POSITION;
    float2 texcoord : TEXCOORD0;
    float3 normal   : TEXCOORD1;
    float3 light    : TEXCOORD2;
    float3 view     : TEXCOORD3;
	float4 shadow   : TEXCOORD4;
	float4 shadow2 	: TEXCOORD5;
	float4 color    : TEXCOORD6;
	float3 tangent  : TEXCOORD7;
	float3 binormal : TEXCOORD8;
};

struct VS_DEFERRED_OUTPUT
{
    float4 vpos     : POSITION;
    float3 texcoord : TEXCOORD0;
    float3 normal   : TEXCOORD1;
	float4 shadow   : TEXCOORD2;
	float4 color    : TEXCOORD3;
	float3 tangent  : TEXCOORD4;
	float3 binormal : TEXCOORD5;
	float3 pos : TEXCOORD6;
};

struct VS_SHADOW_OUTPUT
{
    float4 vpos     : POSITION;
	float depth 	: TEXCOORD1;
	float2 texcoord : TEXCOORD0;
};

struct VS_INPUT
{
    float4 pos      : POSITION;
    float2 texcoord : TEXCOORD0;
    float3 normal   : NORMAL;
	float3 tangent  : TANGENT;
	float4 color    : COLOR;
};

struct Deferred_OUT
{
    float4 col0      : COLOR0;
    float4 col1 	 : COLOR1;
	float4 col2 	 : COLOR2;
	//float4 col3 	 : COLOR3;
};

float4x4 make_bias_mat(float BiasVal)
{
	float fTexWidth = screenWidth;
	float fTexHeight = screenHeight;
	// float fZScale = pow(2.0,((float)SHAD_BIT_DEPTH))-1.0; // dx8
	float fZScale = 1.0; //dx9
	float fOffsetX = 0.5f + (0.5f / fTexWidth);
	float fOffsetY = 0.5f + (0.5f / fTexHeight);
	float4x4 result = float4x4(0.5f,     0.0f,     0.0f,      0.0f,
					0.0f,    -0.5f,     0.0f,      0.0f,
					0.0f,     0.0f,     fZScale,   0.0f,
					fOffsetX, fOffsetY, -BiasVal,     1.0f );
	return result;
}
float3 AutoNormalGen(sampler2D sample,float2 texCoord) {
   float off = 1.0 / 256;
   float4 lightness = float4(0.2,0.59,0.11,0);
   // Take all neighbor samples
   float4 s00 = tex2D(sample, texCoord + float2(-off, -off));
   float4 s01 = tex2D(sample, texCoord + float2( 0,   -off));
   float4 s02 = tex2D(sample, texCoord + float2( off, -off));

   float4 s10 = tex2D(sample, texCoord + float2(-off,  0));
   float4 s12 = tex2D(sample, texCoord + float2( off,  0));

   float4 s20 = tex2D(sample, texCoord + float2(-off,  off));
   float4 s21 = tex2D(sample, texCoord + float2( 0,    off));
   float4 s22 = tex2D(sample, texCoord + float2( off,  off));

   // Slope in X direction
   float4 sobelX = s00 + 2 * s10 + s20 - s02 - 2 * s12 - s22;
   // Slope in Y direction
   float4 sobelY = s00 + 2 * s01 + s02 - s20 - 2 * s21 - s22;

   // Weight the slope in all channels, we use grayscale as height
   float sx = dot(sobelX, lightness);
   float sy = dot(sobelY, lightness);

   // Compose the normal
   float3 normal = normalize(float3(sx, sy, 1));

   // Pack [-1, 1] into [0, 1]
   return normal * 0.5 + 0.5;
}
VS_OUTPUT mainVS(VS_INPUT IN)
{
    VS_OUTPUT OUT;
    float3 wpos = mul(gmWorld, IN.pos).xyz;
    OUT.vpos=mul(gmWorldViewProj,float4(IN.pos.xyz,1.0));
    OUT.normal = (mul(gmWorld, IN.normal.xyz));
    OUT.texcoord = IN.texcoord;
	OUT.shadow = mul(mul(gmLightViewProj,float4(IN.pos.xyz,1.0)),make_bias_mat(0.000018f));
	
    OUT.light = normalize(gvDirLight.xyz-wpos);
    OUT.view = (gvEye-wpos);
	OUT.shadow2 = mul(mul(gmLightViewProj2,float4(IN.pos.xyz,1.0)),make_bias_mat(0.000018f));
	OUT.shadow2.w = distance(wpos,gvEye);
	OUT.color = IN.color;
	OUT.tangent = IN.tangent.xyz;
	OUT.binormal = (mul(gmWorld,normalize(cross(IN.tangent,IN.normal))));
    return OUT;
}

VS_DEFERRED_OUTPUT DeferredVS(VS_INPUT IN)
{
    VS_DEFERRED_OUTPUT OUT;
    float3 wpos = mul(gmWorld, IN.pos).xyz;
    OUT.vpos=mul(gmWorldViewProj,float4(IN.pos.xyz,1.0));
    OUT.normal = (mul(gmWorld, IN.normal.xyz));
    OUT.texcoord.xy = IN.texcoord.xy;
	OUT.texcoord.z = OUT.vpos.z;
	OUT.shadow = mul(mul(gmLightViewProj,float4(IN.pos.xyz,1.0)),make_bias_mat(0.000018f));
	OUT.color = IN.color;
	OUT.tangent = (mul(gmWorld, IN.tangent.xyz));
	OUT.binormal = (mul(gmWorld,(cross(IN.tangent,IN.normal))));
	OUT.pos = mul(gmWorld,float4(IN.pos.xyz,1.0)).xyz;
    return OUT;
}

VS_SHADOW_OUTPUT shadowVS(VS_INPUT IN)
{
    VS_SHADOW_OUTPUT OUT;
    OUT.vpos=mul(gmWorldViewProj, float4(IN.pos.xyz,1.0));
	OUT.depth = mul(gmWorldViewProj, float4(IN.pos.xyz,1.0)).z;
	OUT.texcoord = IN.texcoord;
    return OUT;
}



float4 shadowPS(VS_SHADOW_OUTPUT IN) : COLOR
{
	float4 texColor = tex2D(gsDiffuse, IN.texcoord);
	clip(texColor.a);
	return float4(IN.depth,0,0,texColor.a);
}

float4 mainPS(VS_OUTPUT IN) : COLOR
{
  float3 vNormal = (tex2D( gsNormals, IN.texcoord ));
  vNormal = 2 * vNormal - 1.0;
  float4 texColor = tex2D(gsDiffuse, IN.texcoord);
  float3x3 mTangentToWorld = transpose( float3x3( IN.tangent, IN.binormal, IN.normal ) );
  float3   vNormalWorld    = normalize( mul( mTangentToWorld, vNormal ));
  float4 color = texColor * gvPaintColor;
  float3 H = normalize(IN.light + normalize(IN.view));
  float n  = 16;
  float D  = dot(vNormalWorld, H);
  float shadow = 0;
	for (int y=-2; y<2; y++){
		for (int x=-2; x<2; x++)
		{
			float4 coord = IN.shadow;
			float4 coord2 = IN.shadow2;
			coord.xy += (float2(x,y)/((screenWidth+screenHeight)/4))*IN.shadow.w;
			coord2.xy += (float2(x,y)/((screenWidth+screenHeight)/4))*IN.shadow2.w;
			shadow +=tex2Dproj( shadowSampler, coord );
		}
	}
	shadow/= 8;
  float specular = D/(n-D*n+D);
  specular *= tex2D( gsSpecular, IN.texcoord ).x;
  float shadowingTerm = saturate((max(dot(IN.light,vNormalWorld),0.0)*0.5)*shadow);
  float3 ambient =saturate(lerp(gvAmbientColor2.xyz,gvAmbientColor.xyz,vNormalWorld.z)*(IN.color.xyz*0.5+0.5));
  float3 shadedColor = color * (shadowingTerm+ambient*0.3);
  float4 finalColor;
  finalColor.xyz = shadedColor.xyz + specular * 0.5 * shadow;
  finalColor.a = color.a*IN.color.a;
  return finalColor;
}

Deferred_OUT DeferredPS(VS_DEFERRED_OUTPUT IN)
{
	Deferred_OUT OUT;
	float3 vNormal = (tex2D( gsNormals, IN.texcoord ));
	vNormal = 2 * vNormal - 1.0;
	float3x3 mTangentToWorld = transpose( float3x3( IN.tangent, IN.binormal, IN.normal ) );
	float3   vNormalWorld    = normalize( mul( mTangentToWorld, vNormal ));
	OUT.col0 = tex2D(gsDiffuse, IN.texcoord.xy)* gvPaintColor;
	OUT.col1.xy = vNormalWorld.xy;
	OUT.col1.z = tex2D( gsSpecular, IN.texcoord.xy ).x;
	OUT.col1.w = 1;
	OUT.col2 = float4(IN.pos.x,IN.pos.y,IN.pos.z,IN.texcoord.z);
	//OUT.col2.xyz = IN.pos;
	//OUT.col3 = float4(1,1,1,1);
	return OUT;
}

technique Forward
{
    pass p0
    {
        VertexShader = compile vs_3_0 mainVS();
        PixelShader  = compile ps_3_0 mainPS();
    }
};
technique Deferred
{
    pass p0
    {
        VertexShader = compile vs_2_0 DeferredVS();
        PixelShader  = compile ps_2_0 DeferredPS();
		AlphaBlendEnable=FALSE;
		SEPARATEALPHABLENDENABLE=FALSE;
		AlphaBlendEnable=FALSE;
		ALPHATESTENABLE=TRUE;
		SrcBlend = one;
		DestBlend = zero;
    }
};
technique Shadow
{
    pass p0
    {
        VertexShader = compile vs_3_0 shadowVS();
        PixelShader  = compile ps_3_0 shadowPS();
		COLORWRITEENABLE = false;
		SEPARATEALPHABLENDENABLE=FALSE;
		AlphaBlendEnable=FALSE;
		ALPHATESTENABLE=TRUE;
		SrcBlend = one;
		DestBlend = zero;
    }
};