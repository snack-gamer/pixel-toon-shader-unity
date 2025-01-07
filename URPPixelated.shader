Shader "Custom/URPPixelatedToonOutlined"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        [NoScaleOffset] _DitherTex ("Dither Pattern", 2D) = "gray" {}
        _DitherTiling ("Dither Tiling", Vector) = (16,16,0,0)
        _DitherStrength ("Dither Strength", Range(0, 1)) = 0.5
        _DitherDarkness ("Dither Darkness", Range(0, 1)) = 0.5
        _DitherPixelSize ("Dither Pixel Size", Range(1, 32)) = 1
        [Space(10)]
        _OutlineColor ("Outline Color", Color) = (0,0,0,1)
        _OutlineThickness ("Outline Thickness", Range(0, 10)) = 5
        _OutlinePixelation ("Outline Pixelation", Range(1, 64)) = 1
        _OutlineJaggedness ("Outline Jaggedness", Range(0, 1)) = 0.5
        _OutlineMaxDistance ("Outline Distance Scale", Range(0.1, 10)) = 5
        [Space(10)]
        _ToonRampSmoothness ("Toon Ramp Smoothness", Range(0, 1)) = 0.1
        _ToonRampThreshold ("Toon Ramp Threshold", Range(0, 1)) = 0.5
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows("Receive Shadows", Float) = 1

        // **Enhanced Color Grading Properties**
        [Space(10)]
        _Brightness ("Brightness", Range(-1, 1)) = 0
        _Contrast ("Contrast", Range(0, 2)) = 1
        _Saturation ("Saturation", Range(0, 2)) = 1
        _HueShift ("Hue Shift", Range(0, 360)) = 0
        _ColorBalance ("Color Balance", Vector) = (1,1,1,0) // RGB Balance and an unused component

        // **Emission Property Added**
        [NoScaleOffset] _EmissionMap ("Emission Map", 2D) = "black" {} // **Emission Added**
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "ShaderModel"="2.0"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _OutlineColor;
            float _OutlineThickness;
            float _OutlinePixelation;
            float _OutlineJaggedness;
            float _OutlineMaxDistance;
            float4 _DitherTiling;
            float _DitherStrength;
            float _DitherDarkness;
            float _DitherPixelSize;
            float _ToonRampSmoothness;
            float _ToonRampThreshold;
            // **Color Grading Variables**
            float _Brightness;
            float _Contrast;
            float _Saturation;
            float _HueShift;
            float4 _ColorBalance;

            // **Emission Variables Added**
            float4 _EmissionMap_ST; // **Emission Added**
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_DitherTex);
        SAMPLER(sampler_DitherTex);
        TEXTURE2D(_EmissionMap); // **Emission Added**
        SAMPLER(sampler_EmissionMap); // **Emission Added**
        
        struct Attributes
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float2 uv : TEXCOORD0;
            float4 tangentOS : TANGENT;
        };

        struct Varyings
        {
            float4 positionHCS : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 positionWS : TEXCOORD1;
            float3 normalWS : TEXCOORD2;
            float3 positionOS : TEXCOORD3;
            float3 tangentWS : TEXCOORD4;
            float3 bitangentWS : TEXCOORD5;
        };
        ENDHLSL

        // Outline Pass
        Pass
        {
            Name "Outline"
            Cull Front

            HLSLPROGRAM
            #pragma target 2.0
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma vertex OutlineVert
            #pragma fragment OutlineFrag


            // Simple hash function for mobile
            float hash(float2 p)
            {
                return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
            }

            float3 GetScaledNormal(float3 normalOS, float3 positionOS)
            {
                float3 objectScale = float3(
                    length(unity_ObjectToWorld._m00_m10_m20),
                    length(unity_ObjectToWorld._m01_m11_m21),
                    length(unity_ObjectToWorld._m02_m12_m22)
                );
                
                float avgScale = (objectScale.x + objectScale.y + objectScale.z) / 3.0;
                
                // Make distance scaling more intuitive - larger values = outline extends further
                float distanceScale = _OutlineMaxDistance;
                return normalOS * distanceScale;
            }

            Varyings OutlineVert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                float noise = hash(input.positionOS.xy) * 2.0 - 1.0;
                float3 normalOS = normalize(input.normalOS + noise * _OutlineJaggedness * 0.1);
                float3 scaledNormal = GetScaledNormal(normalOS, input.positionOS.xyz);
                
                // Simplified thickness calculation - direct control
                float thickness = _OutlineThickness * 0.01; // Convert 0-10 range to reasonable world units
                float3 posOS = input.positionOS.xyz + scaledNormal * thickness;
                
                output.positionHCS = TransformObjectToHClip(posOS);
                output.positionOS = input.positionOS.xyz;
                output.uv = input.uv;
                
                return output;
            }

            float4 OutlineFrag(Varyings input) : SV_Target
            {
                float2 pixelatedUV = floor(input.positionOS.xy * _OutlinePixelation) / _OutlinePixelation;
                float noise = hash(pixelatedUV * 1000);
                
                float4 outlineCol = _OutlineColor;
                outlineCol.rgb += (noise * 2.0 - 1.0) * _OutlineJaggedness * 0.2;
                
                return outlineCol;
            }
            ENDHLSL
        }

        // Main Pass
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 2.0
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            
            #pragma vertex LitVert
            #pragma fragment LitFrag
            
            #pragma shader_feature_local _RECEIVE_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            // Function to rotate hue
            float3 HueShiftFunc(float3 color, float angle)
            {
                float rad = radians(angle);
                float cosA = cos(rad);
                float sinA = sin(rad);

                float3x3 rotationMatrix = float3x3(
                    0.213 + cosA * 0.787 - sinA * 0.213, 0.715 - cosA * 0.715 - sinA * 0.715, 0.072 - cosA * 0.072 + sinA * 0.928,
                    0.213 - cosA * 0.213 + sinA * 0.143, 0.715 + cosA * 0.285 + sinA * 0.140, 0.072 - cosA * 0.072 - sinA * 0.283,
                    0.213 - cosA * 0.213 - sinA * 0.787, 0.715 - cosA * 0.715 + sinA * 0.715, 0.072 + cosA * 0.928 + sinA * 0.072
                );

                return mul(rotationMatrix, color);
            }

            float ToonRamp(float value)
            {
                float halfSmooth = _ToonRampSmoothness * 0.5;
                float remap = value - _ToonRampThreshold;
                return saturate((remap + halfSmooth) / _ToonRampSmoothness);
            }

            float2 GetObjectSpaceDitherUV(float3 positionOS, float3 normalWS)
            {
                float3 absNormal = abs(normalWS);
                float2 uv;
                
                if (absNormal.x >= absNormal.y && absNormal.x >= absNormal.z)
                {
                    uv = positionOS.yz;
                }
                else if (absNormal.y >= absNormal.x && absNormal.y >= absNormal.z)
                {
                    uv = positionOS.xz;
                }
                else
                {
                    uv = positionOS.xy;
                }
                
                uv *= _DitherTiling.xy * 0.1;
                uv = floor(uv * _DitherPixelSize) / _DitherPixelSize;
                return frac(uv);
            }

            Varyings LitVert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionHCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = normalInputs.tangentWS;
                output.bitangentWS = normalInputs.bitangentWS;
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.positionOS = input.positionOS.xyz;
                
                return output;
            }

            float4 LitFrag(Varyings input) : SV_Target
            {
                float4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                
                // Apply dithering
                float2 ditherUV = GetObjectSpaceDitherUV(input.positionOS, input.normalWS);
                float dither = SAMPLE_TEXTURE2D(_DitherTex, sampler_DitherTex, ditherUV).r;
                float3 ditherColor = baseColor.rgb * (1.0 - _DitherDarkness * dither);
                baseColor.rgb = lerp(baseColor.rgb, ditherColor, _DitherStrength);

                // Main light
                float3 normalWS = normalize(input.normalWS);
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                
                float NdotL = dot(normalWS, mainLight.direction) * 0.5 + 0.5;
                float toonLight = ToonRamp(NdotL);
                
                // Shadows and ambient
                float shadow = mainLight.shadowAttenuation;
                float3 ambient = SampleSH(normalWS) * 0.2;
                
                // Final lighting
                float3 lighting = mainLight.color * (toonLight * shadow) + ambient;
                float3 litColor = baseColor.rgb * lighting;

                // Additional lights
                #ifdef _ADDITIONAL_LIGHTS
                uint additionalLightsCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0u; lightIndex < additionalLightsCount; ++lightIndex)
                {
                    Light light = GetAdditionalLight(lightIndex, input.positionWS);
                    float addNdotL = dot(normalWS, light.direction) * 0.5 + 0.5;
                    float toonAddLight = ToonRamp(addNdotL);
                    litColor += baseColor.rgb * light.color * (light.distanceAttenuation 
                        * light.shadowAttenuation * toonAddLight * 0.5);
                }
                #endif

                // **Enhanced Color Grading Adjustments**

                // 1. Apply Brightness
                litColor += _Brightness;

                // 2. Apply Contrast
                litColor = (litColor - 0.5) * _Contrast + 0.5;

                // 3. Apply Saturation
                float gray = dot(litColor, float3(0.3, 0.59, 0.11));
                litColor = lerp(float3(gray, gray, gray), litColor, _Saturation);

                // 4. Apply Hue Shift
                litColor = HueShiftFunc(litColor, _HueShift);

                // 5. Apply Color Balance
                litColor *= _ColorBalance.rgb;

                // **Emission Added**
                // Sample the emission texture
                float4 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv); // **Emission Added**
                litColor += emission.rgb; // **Emission Added**

                // Ensure the color stays within [0,1] range
                litColor = saturate(litColor);

                // Apply fog
                float fogFactor = ComputeFogFactor(input.positionHCS.z);
                litColor = MixFog(litColor, fogFactor);

                return float4(litColor, baseColor.a);
            }
            ENDHLSL
        }

        // Shadow Caster Pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            
            HLSLPROGRAM
            #pragma target 2.0
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            
            float3 _LightDirection;

            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                
                #if UNITY_REVERSED_Z
                positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif

                return positionCS;
            }

            Varyings ShadowVert(Attributes input)
            {
                Varyings output = (Varyings)0; // Initialize all fields to 0
                
                output.positionHCS = GetShadowPositionHClip(input);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                
                // Initialize remaining fields required by the Varyings struct
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.positionOS = input.positionOS.xyz;
                output.tangentWS = normalize(TransformObjectToWorldDir(input.tangentOS.xyz));
                output.bitangentWS = normalize(cross(output.normalWS, output.tangentWS) 
                    * input.tangentOS.w);
                
                return output;
            }

            half4 ShadowFrag(Varyings input) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }
    }
}
