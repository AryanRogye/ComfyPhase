#include <metal_stdlib>
using namespace metal;
struct Drop { float4 origin; float4 shape; float4 variation; };
struct Uniforms { float2 viewport; float time; float motion; };
struct Raster {
    float4 position [[position]];
    float2 local;
    float2 screenUV;
    float4 shape [[flat]];
    float4 variation [[flat]];
};
vertex Raster rainVertex(uint vertexID [[vertex_id]], uint instance [[instance_id]],
                        constant Drop *drops [[buffer(0)]], constant Uniforms &u [[buffer(1)]]) {
    const float2 corners[] = {float2(-1,-1),float2(1,-1),float2(-1,1),float2(-1,1),float2(1,-1),float2(1,1)};
    Drop d = drops[instance];
    float2 center = d.origin.xy * u.viewport;
    float t = u.time * u.motion;
    if (d.origin.z > 0) {
        center.y = fmod(center.y + t * d.origin.z, u.viewport.y + 2*d.shape.y) - d.shape.y;
        center.x += sin(t * (0.4 + d.shape.w * 0.3) + d.variation.x) * d.variation.y;
        if (d.variation.w > 0) {
            center.x = fmod(center.x + t * (8 + d.shape.w * 12) + u.viewport.x, u.viewport.x + 2*d.shape.x) - d.shape.x;
        }
    }
    float2 local = corners[vertexID];
    float2 offset = local * d.shape.xy;
    if (d.variation.w > 1.5) {
        // Turn the petal face away and back while it rotates in the glass plane.
        float phase = t * d.variation.z + d.origin.w;
        offset.x *= 0.2 + 0.8 * abs(cos(phase));
        float angle = d.variation.x + t * 0.24 + sin(phase * 0.7) * 0.85;
        float c = cos(angle), s = sin(angle);
        offset = float2(c*offset.x - s*offset.y, s*offset.x + c*offset.y);
    }
    float2 pixel = center + offset;
    Raster out;
    out.position = float4(pixel.x/u.viewport.x*2-1, 1-pixel.y/u.viewport.y*2,0,1);
    out.local = local;
    out.screenUV = pixel/u.viewport;
    out.shape = d.shape;
    out.variation = d.variation;
    return out;
}
fragment float4 rainFragment(Raster in [[stage_in]], constant Uniforms &u [[buffer(1)]], texture2d<float> desktop [[texture(0)]]) {
    constexpr sampler screenSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    // A tapered ellipsoidal lens: its spatially varying normal bends desktop pixels.
    float2 p = in.local;
    float taper = mix(0.72, 1.0, smoothstep(-1.0, 0.4, p.y));
    p.x /= taper;
    float r2 = dot(p,p);
    if (r2 >= 1.0) discard_fragment();
    float z = sqrt(max(0.001, 1-r2));
    float3 normal = normalize(float3(p.x, p.y * in.shape.x/in.shape.y, z));
    // Convex lens magnifies the center, then bends more sharply toward the rim.
    float2 lens = -in.local * in.shape.xy * 0.32 * z;
    float2 displacement = (lens + normal.xy * in.variation.z * (0.35 + 0.65*r2)) * in.shape.w / u.viewport;
    // Match the background view's aspect-fill crop on each monitor.
    float2 uv = in.screenUV + displacement;
    float ratio = (u.viewport.x / u.viewport.y) /
        (float(desktop.get_width()) / float(desktop.get_height()));
    if (ratio < 1) uv.x = (uv.x - 0.5) * ratio + 0.5;
    else uv.y = (uv.y - 0.5) / ratio + 0.5;
    float4 sample = desktop.sample(screenSampler, uv);
    // Texture loader preserves premultiplied image alpha; shade in straight color.
    float3 refracted = sample.a > 0.0001 ? sample.rgb / sample.a : float3(0);
    float rim = pow(1-z, 4.0);
    float shine = pow(max(dot(normal, normalize(float3(-0.45,-0.65,0.8))),0.0), 48.0);
    refracted = refracted * (1 - rim * 0.12) + shine * 0.28 + rim * 0.07;
    float edge = 1-smoothstep(0.92, 1.0, r2);
    float alpha = edge * in.shape.z * sample.a;
    // Premultiplied output; outside these small quads the drawable remains clear.
    return float4(refracted * alpha, alpha);
}

fragment float4 snowFragment(Raster in [[stage_in]]) {
    float r = length(in.local);
    if (r > 1) discard_fragment();
    // Small far flakes and soft, larger foreground flakes share one instanced draw.
    float core = 1 - smoothstep(0.12, 0.8, r);
    float halo = (1 - smoothstep(0.4, 1.0, r)) * 0.18;
    float alpha = min(1.0, core + halo) * in.shape.z;
    return float4(float3(0.92, 0.96, 1.0) * alpha, alpha);
}


fragment float4 blossomFragment(Raster in [[stage_in]]) {
    float2 p = in.local;
    // A rounded, notched sakura petal tapering toward its attachment point.
    float width = mix(0.38, 0.92, smoothstep(-0.95, 0.35, p.y));
    float body = length(float2(p.x / width, p.y)) - 0.92;
    float notch = 0.20 - length(float2(p.x * 1.1, p.y - 0.94));
    float distance = max(body, notch);
    float aa = max(fwidth(distance), 0.01);
    float alpha = (1 - smoothstep(-aa, aa, distance)) * in.shape.z;
    if (alpha < 0.001) discard_fragment();
    float tint = fract(sin(in.variation.x * 12.9898) * 43758.5453);
    float3 base = mix(float3(1.0,0.63,0.76), float3(1.0,0.83,0.89), tint);
    float centerLight = exp(-p.x*p.x*5.0) * 0.07;
    float vein = exp(-abs(p.x - 0.06*sin(p.y*3.0))*55.0) * 0.035;
    float shade = 0.94 + 0.06 * p.x - 0.06 * p.y;
    return float4((base * shade + centerLight - vein) * alpha, alpha);
}

float segmentDistance(float2 p, float2 a, float2 b) {
    float2 ab = b-a;
    return length(p-a-ab*clamp(dot(p-a,ab)/dot(ab,ab),0.0,1.0));
}

fragment float4 autumnFragment(Raster in [[stage_in]]) {
    float2 p = in.local;
    // A long pointed blade, wider near the stem and gently curved along its midrib.
    float along = clamp((p.y + 0.94) / 1.63, 0.0, 1.0);
    float midrib = 0.12 * sin(along * M_PI_F);
    float bladeWidth = 0.76 * pow(max(sin(along * M_PI_F), 0.0), 0.85) * (0.65 + 0.35 * along);
    float body = max(abs(p.x - midrib) - bladeWidth, max(-0.94 - p.y, p.y - 0.69));
    // A short bent stem extending from the base of the blade.
    float stem = min(segmentDistance(p,float2(0,0.63),float2(-0.045,0.81)),
                     segmentDistance(p,float2(-0.045,0.81),float2(-0.13,0.95))) - 0.016;
    float distance = min(body,stem);
    float aa = max(fwidth(distance),0.009);
    float alpha = (1-smoothstep(-aa,aa,distance))*in.shape.z;
    if (alpha<0.001) discard_fragment();
    float seed = fract(sin(in.variation.x*12.9898)*43758.5453);
    float3 gold=float3(1.0,0.65,0.16), orange=float3(0.91,0.33,0.08), red=float3(0.69,0.12,0.10);
    float3 base=seed<0.5 ? mix(gold,orange,seed*2) : mix(orange,red,(seed-0.5)*2);
    float veinDistance = abs(p.x - midrib);
    for (uint i=0; i<4; i++) {
        float y = -0.47 + float(i)*0.27;
        float a = (y + 0.94)/1.63;
        float x = 0.12*sin(a*M_PI_F);
        float w = 0.76*pow(sin(a*M_PI_F),0.85)*(0.65+0.35*a);
        veinDistance = min(veinDistance, segmentDistance(p,float2(x,y+0.17),float2(x+w*0.83,y-0.11)));
        veinDistance = min(veinDistance, segmentDistance(p,float2(x,y+0.17),float2(x-w*0.83,y-0.11)));
    }
    float veins = 1-smoothstep(0.003,0.020,veinDistance);
    float shading = 0.90+0.10*(p.x-midrib)+0.04*sin(p.y*5+in.variation.x);
    return float4(base*(shading-veins*0.15)*alpha,alpha);
}
