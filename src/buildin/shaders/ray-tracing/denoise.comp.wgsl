let WINDOW_SIZE: i32 = ${WINDOW_SIZE};

fn calcWeightNumber(params: vec2<f32>, a: f32, b: f32) -> f32 {
  return params.x * exp(params.y * abs(a - b));
}

fn calcWeightVec2(params: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
  return params.x * exp(params.y * abs(dot(a, b)));
}

fn calcWeightVec3(params: vec2<f32>, a: vec3<f32>, b: vec3<f32>) -> f32 {
  return params.x * exp(params.y * abs(dot(a, b)));
}

fn blur(center: vec2<i32>, size: vec2<i32>) -> vec4<f32> {
  let radius: i32 = WINDOW_SIZE / 2;
  let zigmaD: vec2<f32> = material.u_filterFactors[0];
  let zigmaC: vec2<f32> = material.u_filterFactors[1];
  let zigmaZ: vec2<f32> = material.u_filterFactors[2];
  let zigmaN: vec2<f32> = material.u_filterFactors[3];
  let centerColor: vec4<f32> = textureLoad(u_current, center);
  let centerPosition = textureLoad(u_gbPositionMetal, center, 0).xyz;
  let centerNormal = textureLoad(u_gbPositionMetal, center, 0).xyz;

  var weightsSum: f32 = 0.;
  var res: vec3<f32> = vec3<f32>(0., 0., 0.);

  for (var r: i32 = -radius; r <= radius; r = r + 1) {
    for (var c: i32 = -radius; c <= radius; c = c + 1) {
      let iuv: vec2<i32> = center + vec2<i32>(r, c);

      if (any(iuv < vec2<i32>(0)) || any(iuv >= size)) {
        continue;
      }

      let color: vec3<f32> = textureLoad(u_current, iuv).rgb;
      let position = textureLoad(u_gbPositionMetal, iuv, 0).xyz;
      let normal = textureLoad(u_gbPositionMetal, iuv, 0).xyz;
      let weight: f32 = calcWeightVec2(zigmaD, vec2<f32>(f32(r), f32(c)), vec2<f32>(0.))
        * calcWeightVec3(zigmaC, color, centerColor.rgb)
        * calcWeightVec3(zigmaC, normal, centerNormal)
        * calcWeightNumber(zigmaC, position.z, centerPosition.z);
      // todo: normal weights, meshid weights...
      weightsSum = weightsSum + weight;
      res = res + weight * color;
    }
  }

  return vec4<f32>(res / f32(weightsSum), centerColor.a);
}

[[stage(compute), workgroup_size(16, 16, 1)]]
fn main(
  [[builtin(workgroup_id)]] workGroupID : vec3<u32>,
  [[builtin(local_invocation_id)]] localInvocationID : vec3<u32>
) {
  let size: vec2<i32> = textureDimensions(u_current);
  let groupOffset: vec2<i32> = vec2<i32>(workGroupID.xy) * 16;
  let baseIndex: vec2<i32> = groupOffset + vec2<i32>(localInvocationID.xy);

  let pre: vec4<f32> = textureLoad(u_pre, baseIndex);
  var current: vec4<f32>;
  if (baseIndex.x > size.x / 2) {
    current = blur(baseIndex, size);
  } else {
    current = textureLoad(u_current, baseIndex);
  }

  textureStore(u_output, baseIndex, vec4<f32>(mix(current.rgb, pre.rgb, material.u_preWeight), 1.));
  // textureStore(u_output, baseIndex, current);
}
