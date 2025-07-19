Shader "Hidden/Shader/HybridKuwahara"
{
    Properties
    {
        // This property is necessary to make the CommandBuffer.Blit bind the source texture to _MainTex
        _MainTex("Main Texture", 2DArray) = "grey" {}
    }

    HLSLINCLUDE

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/FXAA.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/RTUpscale.hlsl"

    struct Attributes
    {
        uint vertexID : SV_VertexID;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float2 texcoord   : TEXCOORD0;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    Varyings Vert(Attributes input)
    {
        Varyings output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
        output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
        output.texcoord = GetFullScreenTriangleTexCoord(input.vertexID);
        return output;
    }

    #define PI 3.14159265358979323846f

    // List of properties to control your post process effect
    TEXTURE2D_X(_MainTex);

    //sampler2D _MainTex;
    float2 _MainTex_TexelSize;
    float _Intensity;
    int _KernelSize;
    float _Overlap, _Sharpness, _Scaling;

    float4 m[4];
    float3 s[4];

    float gaussian(int x)
    {
        float sigmaSqu = 1;
        return (1 / sqrt(2 * PI * sigmaSqu)) * exp(-(x * x) / (2 * sigmaSqu));
    }

    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        // Note that if HDUtils.DrawFullScreen is not used to render the post process, you don't need to call ClampAndScaleUVForBilinearPostProcessTexture.

        float3 sourceColor = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler, ClampAndScaleUVForBilinearPostProcessTexture(input.texcoord.xy)).xyz;

        int radius = _KernelSize * 0.5f;
        float overlap = ((float) radius * 0.5f) * (float)_Overlap;
        float halfOverlap = overlap / 2;
        //float halfOverlap = 0;
        float maxV = length(float2(radius,radius));

        //SOBEL OPERATOR

        float2 d = _MainTex_TexelSize.xy;

        float3 col_dx_0 = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler, ClampAndScaleUVForBilinearPostProcessTexture(input.texcoord.xy + float2(d.x, 0.0))).rgb;
        float3 col_mdx_0 = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler, ClampAndScaleUVForBilinearPostProcessTexture(input.texcoord.xy + float2(-d.x, 0.0))).rgb;
        float3 col_0_dy = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler, ClampAndScaleUVForBilinearPostProcessTexture(input.texcoord.xy + float2(0.0, d.y))).rgb;
        float3 col_0_mdy = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler, ClampAndScaleUVForBilinearPostProcessTexture(input.texcoord.xy + float2(0.0, -d.y))).rgb;
        float3 col_mdx_mdy = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler, ClampAndScaleUVForBilinearPostProcessTexture(input.texcoord.xy + float2(-d.x, -d.y))).rgb;
        float3 col_mdx_dy = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler, ClampAndScaleUVForBilinearPostProcessTexture(input.texcoord.xy + float2(-d.x, d.y))).rgb;
        float3 col_dx_mdy = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler, ClampAndScaleUVForBilinearPostProcessTexture(input.texcoord.xy + float2(d.x, -d.y))).rgb;
        float3 col_dx_dy = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler, ClampAndScaleUVForBilinearPostProcessTexture(input.texcoord.xy + float2(d.x, d.y))).rgb;


        // float3 Sx = (
        //     1.0f * tex2D(_MainTex, i.uv + float2(-d.x, -d.y)).rgb +
        //     2.0f * tex2D(_MainTex, i.uv + float2(-d.x, 0.0)).rgb +
        //     1.0f * tex2D(_MainTex, i.uv + float2(-d.x, d.y)).rgb +
        //     -1.0f * tex2D(_MainTex, i.uv + float2(d.x, -d.y)).rgb +
        //     -2.0f * tex2D(_MainTex, i.uv + float2(d.x, 0.0)).rgb +
        //     -1.0f * tex2D(_MainTex, i.uv + float2(d.x, d.y)).rgb
        //     ) / 4;

        float3 Sx = (
            1.0f * col_mdx_mdy +
            2.0f * col_mdx_0 +
            1.0f * col_mdx_dy +
            -1.0f * col_dx_mdy +
            -2.0f * col_dx_0 +
            -1.0f * col_dx_dy
            ) / 4;

        // float3 Sy = (
        //     1.0f * tex2D(_MainTex, i.uv + float2(-d.x, -d.y)).rgb +
        //     2.0f * tex2D(_MainTex, i.uv + float2(0.0, -d.y)).rgb +
        //     1.0f * tex2D(_MainTex, i.uv + float2(d.x, -d.y)).rgb +
        //     -1.0f * tex2D(_MainTex, i.uv + float2(-d.x, d.y)).rgb +
        //     -2.0f * tex2D(_MainTex, i.uv + float2(0.0, d.y)).rgb +
        //     -1.0f * tex2D(_MainTex, i.uv + float2(d.x, d.y)).rgb
        //     ) / 4;

        float3 Sy = (
            1.0f * col_mdx_mdy +
            2.0f * col_0_mdy +
            1.0f * col_dx_mdy +
            -1.0f * col_mdx_dy +
            -2.0f * col_0_dy +
            -1.0f * col_dx_dy
            ) / 4;

        float greyscale = float3(0.2126, 0.7152, 0.0722);
        float gradientX = dot(Sx, greyscale);
        float gradientY = dot(Sy, greyscale);

        
        float lineArt = max(gradientX, gradientY);
        lineArt = abs(lineArt);

        int2 offs[4] = { {-radius + overlap, -radius + overlap}, {-radius + overlap, 0}, {0, -radius + overlap}, {0,0} };

        float angle = atan(gradientY / gradientX);

        float sinPhi = sin(angle);
        float cosPhi = cos(angle);

        for (int x = 0; x < radius; ++x)
        {
            for (int y = 0; y < radius; ++y)
            {
                for (int k = 0; k < 4; ++k)
                {
                    float2 v = float2(x, y);
                    v += offs[k] - float2(halfOverlap, halfOverlap);
                    float2 offset = v * _MainTex_TexelSize.xy;
                    //fixed2 offset = (v + offs[k]) * _MainTex_TexelSize.xy;
                    //v = v + offs[k];
                    //fixed2 offset = v * _MainTex_TexelSize.xy;
                    offset = float2(offset.x * cosPhi - offset.y * sinPhi, offset.x * sinPhi + offset.y * cosPhi);
                    float3 tex = SAMPLE_TEXTURE2D_X(_MainTex, s_linear_clamp_sampler, ClampAndScaleUVForBilinearPostProcessTexture(input.texcoord.xy + offset)).rgb;
                    //float w = 1-(length(v)/(float)radius);
                    float w = gaussian(length(v)/5);
                    //float w = 1;
                    m[k] += float4(tex * w, w);
                    s[k] += tex * tex * w;


                }
            }
        }

        float4 result = 0;

        for (int k = 0; k < 4; ++k)
        {
            m[k].rgb /= m[k].w;
            s[k] = abs((s[k] / m[k].w) - (m[k].rgb * m[k].rgb));
            float sigma2 = s[k].r + s[k].g + s[k].b;
            float w = 1.0f / (1.0f + pow(10000.0f * sigma2 * _Sharpness, 0.5 * _Sharpness));
            result += float4(m[k].rgb * w, w);
        }

        result.rgb = result.rgb / result.w;
        float3 final = lerp(result.rgb, lerp(lineArt, lineArt * result.rgb, 0.85f) * 0.5f + result.rgb, _Scaling);
        return float4(lerp(sourceColor, final, _Intensity), 1.0);
        
    }

    ENDHLSL

    SubShader
    {
        Tags{ "RenderPipeline" = "HDRenderPipeline" }
        Pass
        {
            Name "HybridKuwara"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment CustomPostProcess
                #pragma vertex Vert
            ENDHLSL
        }
    }
    Fallback Off
}
