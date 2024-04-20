#include "ReShade.fxh"

uniform float x_off_r <
	ui_type = "drag";
	ui_min = -1.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_label = "X Offset Red [Technicolor]";
> = 0.05;

uniform float y_off_r <
	ui_type = "drag";
	ui_min = -1.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_label = "Y Offset Red [Technicolor]";
> = 0.05;

uniform float x_off_g <
	ui_type = "drag";
	ui_min = -1.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_label = "X Offset Green [Technicolor]";
> = -0.05;

uniform float y_off_g <
	ui_type = "drag";
	ui_min = -1.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_label = "Y Offset Green [Technicolor]";
> = -0.05;

uniform float x_off_b <
	ui_type = "drag";
	ui_min = -1.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_label = "X Offset Blue [Technicolor]";
> = -0.05;

uniform float y_off_b <
	ui_type = "drag";
	ui_min = -1.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_label = "Y Offset Blue [Technicolor]";
> = 0.05;

uniform float grain_str <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 16.0;
	ui_step = 1.0;
	ui_label = "Grain Strength [Technicolor]";
> = 12.0;

uniform float scratch_chance <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.01;
	ui_label = "Scratch Chance [Technicolor]";
	ui_tooltip = "0.0 always straight, 0.5 every frame, 1.0 off";
> = 0.99;

uniform int scratch_frame <
	ui_type = "drag";
	ui_min = 1;
	ui_max = 5;
	ui_step = 1;
	ui_label = "Scratch frame persistence [Technicolor]";
> = 0.99;

uniform float3 scratch_contrast <
	ui_type = "drag";
	ui_min = -10.0;
	ui_max = 10.0;
	ui_step = 0.01;
	ui_label = "Scratch Contrast [Technicolor]";
	ui_tooltip = "Color Offset, Color Mul, Alpha Mul";
> = float3(0, 2.4, -1.96);

uniform float cel_rot <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 0.02;
	ui_step = 0.0001;
	ui_label = "Celluloid rattling [Technicolor]";
> = 0;

uniform float cel_rot_speed <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 4;
	ui_step = 0.01;
	ui_label = "Celluloid rattling speed [Technicolor]";
> = 1;

uniform bool lut_toggle <
	ui_type = "boolean";
	ui_label = "LUT Toggle [Technicolor]";
> = true;

uniform bool hotspot <
	ui_type = "boolean";
	ui_label = "Hotspot Toggle [Technicolor]";
> = true;

uniform bool vignette <
	ui_type = "boolean";
	ui_label = "Vignette Toggle [Technicolor]";
> = true;

uniform bool noise_toggle <
	ui_type = "boolean";
	ui_label = "Film Scratches";
> = true;

uniform int FrameCount < source = "framecount"; >;
uniform float Timer < source = "timer"; >;
// uniform int FrameRand < source = "random"; min = -1000; max = 1000; >;

uniform float2 ppAnim0 < source = "pingpong"; min = -1; max = 1; step = 1; smoothing = 1; >;
uniform float2 ppAnim1 < source = "pingpong"; min = -1; max = 1; step = 0.9; smoothing = 0.9; >;
uniform float2 ppAnim2 < source = "pingpong"; min = -1; max = 1; step = 1.1; smoothing = 1.1; >;

float ppAnim(float offs, float speed)
{
	float t = Timer + offs;
	float t0 = (t * 0.001 + ppAnim0.x * 0.24) * speed;
	float t1 = (t * 0.001 + ppAnim1.x * 0.24) * speed;
	float t2 = (t * 0.001 + ppAnim2.x * 0.24) * speed;
	return sin(t0 * 0.25 + 22) * 0.6 + cos(t1 * 0.5 + 19) * 0.2 + sin(t2 + 72) * 0.2 + cos(t0 * 1.9 + 91) * 0.1 + sin(t1 * 2.1 + 10) * 0.1;
}

texture texCMYKLUT < source = "CMYK.png"; > { Width = 256; Height = 16; Format = RGBA8; };
sampler	SamplerCMYKLUT 	{ Texture = texCMYKLUT; };

texture texFilmNoise < source = "film_noise1.png"; > { Width = 910; Height = 480; Format = RGBA8; };
sampler	SamplerFilmNoise {Texture = texFilmNoise; AddressU = WRAP; AddressV = WRAP; };

#define mod(x,y) (x-y*floor(x/y))

float2x2 rot(float rad)
{
	return float2x2(cos(rad), -sin(rad), sin(rad), cos(rad));
}

//https://www.shadertoy.com/view/4sXSWs strength= 16.0
float filmGrain(float2 uv, float strength, float timer ){       
    float x = (uv.x + 4.0 ) * (uv.y + 4.0 ) * ((mod(timer, 800.0) + 10.0) * 10.0);
	return  (mod((mod(x, 13.0) + 1.0) * (mod(x, 123.0) + 1.0), 0.01)-0.005) * strength;
}

float hash( float n ){
    return frac(sin(n)*43758.5453123);
}

void PS_CMYK_LUT(float4 vpos : SV_Position, float2 texcoord : TEXCOORD, out float4 res : SV_Target0)
{

	float4 color = tex2D(ReShade::BackBuffer, texcoord.xy);
	float2 texelsize = 1.0 / 16;
	texelsize.x /= 16;
	
	float3 lutcoord = float3((color.xy*16-color.xy+0.5)*texelsize.xy,color.z*16-color.z);
	
	float lerpfact = frac(lutcoord.z);
	lutcoord.x += (lutcoord.z-lerpfact)*texelsize.y;

	float3 lutcolor = lerp(tex2D(SamplerCMYKLUT, lutcoord.xy).xyz, tex2D(SamplerCMYKLUT, float2(lutcoord.x+texelsize.y,lutcoord.y)).xyz,lerpfact);

	if (lut_toggle){
	color.xyz = lerp(normalize(color.xyz), normalize(lutcolor.xyz), 1.0) * 
	            lerp(length(color.xyz),    length(lutcolor.xyz),    1.0);
	} else {
		color.xyz = lerp(normalize(color.xyz), normalize(lutcolor.xyz), 0.0) * 
	            lerp(length(color.xyz),    length(lutcolor.xyz),    0.0);
	}

	res.xyz = color.xyz;
	res.w = 1.0;
}

void PS_Technicolor_Noise(in float4 pos : SV_POSITION, in float2 texcoord : TEXCOORD0, out float4 gl_FragCol : COLOR0)
{
// a simple calculation for the vignette/hotspot effects
	float2 middle = texcoord.xy - 0.5;
	float len = length(middle);
	float vig = smoothstep(0.0, 1.0, len);
	int framec = FrameCount / scratch_frame;

// create the noise effects from a LUT of actual film noise
	float2 asp = float2(BUFFER_ASPECT_RATIO, 1);
	float randRot = hash(mod(float(framec), 22.0)) * 3.1459;
	float2 scratchUv = mul((texcoord.xy-0.5) * asp, rot(randRot)) / asp + 0.5;
	float4 film_noise1 = tex2D(SamplerFilmNoise, texcoord.xx *
		sin(hash(mod(float(framec), 47.0))));
	float4 film_noise2 = tex2D(SamplerFilmNoise, scratchUv *
		cos(hash(mod(float(framec), 92.0))));
	
	float colRot = ppAnim(34, 5 * cel_rot_speed) * cel_rot;
	float2 colOffs = float2(
		ppAnim(22, 4.73 * cel_rot_speed),
		ppAnim(100, 5.2 * cel_rot_speed)
	) * cel_rot;
	float2 colUv = mul((texcoord.xy-0.5) * asp, rot(colRot)) / asp + 0.5 + colOffs;

	float2 red_coord = colUv + 0.01 * float2(x_off_r, y_off_r);
	float3 red_light = tex2D(ReShade::BackBuffer, red_coord).rgb;
	float2 green_coord = colUv + 0.01 * float2(x_off_g, y_off_g);
	float3 green_light = tex2D(ReShade::BackBuffer, green_coord).rgb;
	float2 blue_coord = colUv + 0.01 * float2(x_off_r, y_off_r);
	float3 blue_light = tex2D(ReShade::BackBuffer, blue_coord).rgb;

	float3 film = float3(red_light.r, green_light.g, blue_light.b);
	film += filmGrain(texcoord.xy, grain_str, float(framec)); // Film grain

	film *= (vignette > 0.5) ? (1.0 - vig) : 1.0; // Vignette
	film += ((1.0 - vig) * 0.2) * hotspot; // Hotspot

// Apply noise effects (or not)
	if (hash(float(framec)) > scratch_chance && noise_toggle > 0.5)
		gl_FragCol = float4(lerp(film, film_noise1.rgb * scratch_contrast.y + scratch_contrast.x, film_noise1.a * scratch_contrast.z), 1.0);
	else if (hash(float(framec)) < (1-scratch_chance) && noise_toggle > 0.5)
		gl_FragCol = float4(lerp(film, film_noise2.rgb * scratch_contrast.y + scratch_contrast.x, film_noise2.a * scratch_contrast.z), 1.0);
	else
		gl_FragCol = float4(film, 1.0);
} 

technique Technicolor
{
	pass Technicolor_P1
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CMYK_LUT;
	}
	pass Technicolor_P2
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_Technicolor_Noise;
	}
}