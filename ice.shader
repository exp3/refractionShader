Shader "Custom/ice"
{
    Properties
    {
        _color("color", Color) =(1.0, 1.0, 1.0,1.0)
        _MainTex("Main Texture", 2D) = "white" {}
        _ObjectRefraction("Object Refraction", Range(0.0,2.0)) = 1.2
        _FieldRefraction("Field Refraction", Range(0.0,2.0)) = 1
        [PowerSlider(5)]_Distance("Distance", Range(0,100)) = 10.0
        [MaterialToggle] _FresnelSwitch ("FresnelSwitch", Float) = 1 
        _Reflection("Reflection",Range(0.0, 1.0)) = 0
        _NormalTex("NormalMap texture", 2D) = "bump" {}
        _NormalMapDistortion("Normal Map Distortion",Range(0.0, 1.0)) = 1.0
    }

    SubShader
    {
        Tags 
        { 
            "Queue" = "Transparent"
            "RenderType" = "Transparent" 
        }
        

        Cull Back 
        ZWrite On
        ZTest LEqual
        ColorMask RGB
        
        GrabPass {"_GrabPassTexture" }
        
        Pass{
            CGPROGRAM 

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                half4 vertex                 : POSITION;
                half4 texcoord               : TEXCOORD0;
                half3 normal                 : NORMAL;  
                half3 tangent                : TANGENT;
            };

            struct v2f
            {
                half4 vertex                 : SV_POSITION;
                half2 samplingViewportPos    : TEXCOORD0;
                half3 tangent                : TANGENT;
                half3 biNormal               : TEXCOORD1;
                half2 uv                     : TEXCOORD2;
                half3 objNormal              : TEXCOORD3;
                half3 viewDir                : TEXCOORD4;

            };

            sampler2D _GrabPassTexture;
            sampler2D _NormalTex;
            sampler2D _MainTex;

            float _ObjectRefraction;
            float _FieldRefraction;
            float _Distance;            
            float _Reflection;
            float _NormalMapDistortion;
            float _FresnelSwitch;
            half4 _color;


            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                o.vertex = UnityObjectToClipPos(v.vertex);
                half refraction = _FieldRefraction/_ObjectRefraction;
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex);
                half3 Normal = UnityObjectToWorldNormal(v.normal); 

                half3 viewDir = normalize(worldPos - _WorldSpaceCameraPos.xyz);

                half3 refrectedDir = refract(viewDir, Normal, refraction);

                half3 samplingPos = worldPos + refrectedDir * _Distance;

                half4 samplingScreenPos = mul(UNITY_MATRIX_VP, half4(-samplingPos, 1.0));

                o.uv = v.texcoord;

                o.samplingViewportPos = samplingScreenPos.xy / samplingScreenPos.w;
                o.viewDir   = normalize(ObjSpaceViewDir(v.vertex));
                o.objNormal = normalize(v.normal.xyz);
                o.tangent = v.tangent;
                o.biNormal = cross(o.objNormal, v.tangent.xyz);

                #if UNITY_UV_START_AT_TOP
                    o.samplingViewportPos.y = 1.0 - o.samplingViewportPos.y;
                #endif

                return o;
            }

            float4x4 TangentMatrix(float3 tan, float3 bin, float3 nor)
            {
                float4x4 mat = float4x4(
                    float4(tan, 0),
                    float4(bin, 0),
                    float4(nor, 0),
                    float4(0, 0, 0, 1)
                );
                return mat;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 tex = tex2D(_MainTex, i.uv);
                half3 normal = UnpackNormal(tex2D(_NormalTex, i.uv));
                half f0 = _Reflection;
                half fon = _FresnelSwitch;

                normal = mul(normal, TangentMatrix(i.tangent, i.biNormal, i.objNormal));
                half vdotn = dot(i.viewDir, normalize(normal));
                half fresnel = ( f0 + (1.0h - f0) * pow(1.0h - vdotn, 5) ) * _FresnelSwitch;

                ;

                i.samplingViewportPos.x = (i.samplingViewportPos.x + (normal.x * _NormalMapDistortion) + 1) * 0.5;
                i.samplingViewportPos.y = (i.samplingViewportPos.y + (normal.y * _NormalMapDistortion) + 1) * 0.5;

                return tex2D(_GrabPassTexture, i.samplingViewportPos) * _color * tex + fresnel * _FresnelSwitch;
            }

            ENDCG
        }
    }
}
