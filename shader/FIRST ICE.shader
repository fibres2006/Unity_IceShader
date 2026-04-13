
Shader "Custom/IceShader_EnhancedWhiteFog"
{
    Properties
    {     
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _CrackTex ("Crack/Detail (RGB)", 2D) = "white" {}

        _IceColor ("Ice Tint", Color) = (0.85,0.95,1,1)
        _AbsorbColor ("Absorption Color (tint inside)", Color) = (0.5,0.75,1,1)

        _BumpScale ("Normal Strength", Range(0,2)) = 1.0
        _CrackStrength ("Crack Intensity", Range(0,2)) = 1.5

        _RefractionStrength ("Refraction Amount", Range(0,0.2)) = 0.09
        _FresnelPower ("Fresnel Power", Range(0.5,8)) = 2.0
        _FresnelIntensity ("Fresnel Intensity", Range(0,2)) = 1.2

        _Gloss ("Metallic/Specular", Range(0,1)) = 0.0
        _Smoothness ("Smoothness", Range(0,1)) = 0.7
        _SpecColor ("Specular Color", Color) = (1,1,1,1)

        _RimColor ("Rim Glow Color", Color) = (0.8,0.95,1,1)
        _RimPower ("Rim Power", Range(1,8)) = 5.0
        _RimIntensity ("Rim Intensity", Range(0,2)) = 0.6

        _Transparency ("Overall Alpha", Range(0,1)) = 0.6

        // 可控制的内部白雾层参数
        _InternalWhiteColor ("Internal White Color", Color) = (1,1,1,1)
        _InternalWhiteIntensity ("Internal White Intensity", Range(0,2)) = 0.6
        _InternalWhiteDepth ("Internal White Depth", Range(0.1,5)) = 2.0
        
        // 雾的位置控制
        _FogCenter ("Fog Center Position (XYZ)", Vector) = (0, 0, 0, 0)
        _FogSize ("Fog Size (XYZ)", Vector) = (1, 1, 1, 0)
        _FogFalloff ("Fog Edge Falloff", Range(0.1, 5)) = 1.0
        _FogShape ("Fog Shape (0=Sphere, 1=Box)", Range(0, 1)) = 0
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 200
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Back


        ZWrite Off

        GrabPass { "_GrabTexture" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            sampler2D _NormalMap;
            sampler2D _CrackTex;
            sampler2D _GrabTexture;

            float4 _IceColor;
            float4 _AbsorbColor;
            float _BumpScale;
            float _CrackStrength;
            float _RefractionStrength;
            float _FresnelPower;
            float _FresnelIntensity;
            float _Gloss;
            float _Smoothness;
            float4 _SpecColor;
            float4 _RimColor;
            float _RimPower;
            float _RimIntensity;
            float _Transparency;

            float4 _InternalWhiteColor;
            float _InternalWhiteIntensity;
            float _InternalWhiteDepth;
            
            float3 _FogCenter;
            float3 _FogSize;
            float _FogFalloff;
            float _FogShape;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
                float4 screenPos : TEXCOORD4;
                float3 objectPos : TEXCOORD5;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.viewDir = _WorldSpaceCameraPos - o.worldPos;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.screenPos = ComputeGrabScreenPos(o.pos);
                o.objectPos = v.vertex.xyz;
                return o;
            }

            float fresnelFactor(float3 viewDir, float3 normal, float power)
            {
                float vn = saturate(dot(normalize(viewDir), normalize(normal)));
                return pow(1 - vn, power);
            }

            // 计算点到雾区域的距离场
            float fogDistanceField(float3 pos, float3 center, float3 size, float shape)
            {
                float3 offset = pos - center;
                
                // 球形雾
                float sphereDist = length(offset / size);
                
                // 盒形雾
                float3 d = abs(offset / size) - 1.0;
                float boxDist = length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
                
                // 在球形和盒形之间插值
                return lerp(sphereDist, boxDist, shape);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv;
                float3 V = normalize(i.viewDir);
                float3 worldN = normalize(i.worldNormal);

                fixed4 baseCol = tex2D(_MainTex, uv) * _IceColor;
                fixed4 nrmSample = tex2D(_NormalMap, uv);
                float3 nrm = UnpackNormal(nrmSample);
                nrm.xy *= _BumpScale;
                worldN = normalize(worldN + nrm);

                fixed4 crack = tex2D(_CrackTex, uv);
                float crackMask = saturate(dot(crack.rgb, float3(0.333,0.333,0.333)) * _CrackStrength);

                float f = fresnelFactor(i.viewDir, worldN, _FresnelPower) * _FresnelIntensity;

                float2 grabUV = i.screenPos.xy / i.screenPos.w;
                float2 offset = (nrm.xy * _RefractionStrength) * (1.0 - crackMask*0.5);
                fixed4 sceneCol = tex2D(_GrabTexture, grabUV + offset);

                fixed4 absorbed = lerp(sceneCol, _AbsorbColor, 0.35 + crackMask*0.4);

                // === 可控制位置的内部白色雾层效果 ===
                
                // 1. 计算到雾中心的距离
                float fogDist = fogDistanceField(i.objectPos, _FogCenter, _FogSize, _FogShape);
                
                // 2. 根据距离和衰减参数计算雾的强度
                float fogDistanceMask = saturate(1.0 - fogDist * _FogFalloff);
                fogDistanceMask = pow(fogDistanceMask, 2.0); // 让边缘更柔和
                
                // 3. 基于视角深度的渐变
                float viewDepth = 1.0 - saturate(dot(V, worldN));
                float depthFade = pow(viewDepth, _InternalWhiteDepth);
                
                // 4. 与菲涅尔反向混合（边缘透明，内部有雾）
                float inverseFresnel = 1.0 - f;
                
                // 5. 综合所有因素
                float fogMask = fogDistanceMask * depthFade * inverseFresnel;
                fogMask = saturate(fogMask);
                
                // 6. 根据裂纹调整雾的分布
                fogMask *= (1.0 - crackMask * 0.3);
                
                float3 innerWhite = _InternalWhiteColor.rgb * fogMask * _InternalWhiteIntensity;

                // === 边缘光与高光 ===
                float rim = pow(1.0 - saturate(dot(V, worldN)), _RimPower) * _RimIntensity;
                float3 rimCol = _RimColor.rgb * rim;

                float3 L = normalize(_WorldSpaceLightPos0.xyz);
                float3 H = normalize(L + V);
                float NdotH = saturate(dot(worldN, H));
                float spec = pow(NdotH, 1.0 / max(0.001, 1.0 - _Smoothness + 0.01) * 50.0) * _Gloss;
                float3 specCol = _SpecColor.rgb * spec * 0.2;

                // === 综合颜色层 ===
                float3 col = baseCol.rgb;
                col = lerp(col, absorbed.rgb, 0.6);
                
                // 叠加白雾
                col = lerp(col, col + innerWhite, 0.8);
                col += innerWhite * 0.3;
                
                col += rimCol * 0.5;
                col += specCol;

                float alpha = saturate(_Transparency + f * 0.25 - crackMask * 0.2);
                alpha = lerp(alpha, alpha * 0.6, crackMask);
                alpha = saturate(alpha + fogMask * 0.2);

                return fixed4(col, alpha);
            }
            ENDCG
        }
    }
    FallBack "Transparent/Cutout/VertexLit"
}