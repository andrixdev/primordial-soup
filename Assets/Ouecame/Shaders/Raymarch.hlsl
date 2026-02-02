// Based on code from Unity x NikLever https://www.youtube.com/watch?v=hXYOlXVRRL8
// Itself based on code from DMEville https://www.youtube.com/watch?v=0G8CVQZhMXw

// Uses 3D texture and lighting 
void raymarch_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize,
                    float densityScale, UnityTexture3D volumeTex, UnitySamplerState volumeSampler,
                    float3 offset, float numLightSteps, float lightStepSize, float3 lightDir,
                    float lightAbsorb, float darknessThreshold, float transmittance, out float3 result)
{
	float density = 0;
	float transmission = 0;
	float lightAccumulation = 0;
	float finalLight = 0;

	for (int i = 0; i < numSteps; i++) {
		rayOrigin += rayDirection * stepSize;

		// The blue dot position
		float3 samplePos = rayOrigin + offset;
		float sampledDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, samplePos).r;
		density += sampledDensity * densityScale;

		// Light loop
		float3 lightRayOrigin = samplePos;
		
		for(int j = 0; j < numLightSteps; j++) {
			// The red dot position
			lightRayOrigin += -lightDir * lightStepSize;
			float lightDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, lightRayOrigin).r;
			// The accumulated density from samplePos to the light - the higher this value the less light reaches samplePos
			lightAccumulation += lightDensity;
		}

		// The amount of light received along the ray from param rayOrigin in the direction rayDirection
        float lightTransmission = exp(-lightAccumulation);
		
		// Shadow tends to the darkness threshold as lightAccumulation rises
		float shadow = darknessThreshold + lightTransmission * (1.0 - darknessThreshold);
		
		// The final light value is accumulated based on the current density, transmittance value and the calculated shadow value 
		finalLight += density * transmittance * shadow;
		
		// Initially a param its value is updated at each step by lightAbsorb, this sets the light lost by scattering
		transmittance *= exp(-density * lightAbsorb);
					
	}

    transmission = exp(-density);

	result = float3(finalLight, transmission, transmittance);
}

bool is_within_bounds(float3 pos) // extended a bit from [-0.5, 0.5]
{
	return ((pos.x > -0.65) && (pos.x < 0.65) && (pos.y > -0.65) && (pos.y < 0.65) && (pos.z > -0.65) && (pos.z < 0.65));
}

float polish_factor(float3 pos, float polishDistance) // Smooth edges values to dark
{
	float res = 1;
	if (polishDistance > 0) {
		float xRamp1 = (1 - 2 * pos.x) / (2 * polishDistance);
		float xRamp2 = (1 + 2 * pos.x) / (2 * polishDistance);
		float xPolish = min(xRamp1, xRamp2);

		float yRamp1 = (1 - 2 * pos.y) / (2 * polishDistance);
		float yRamp2 = (1 + 2 * pos.y) / (2 * polishDistance);
		float yPolish = min(yRamp1, yRamp2);

		float zRamp1 = (1 - 2 * pos.z) / (2 * polishDistance);
		float zRamp2 = (1 + 2 * pos.z) / (2 * polishDistance);
		float zPolish = min(zRamp1, zRamp2);

		float polish = min(xPolish, min(yPolish, zPolish));

		res = max(0, min(1, polish));
	}

	return res;
}

float cartoonize_density(float density, float cartoonThreshold)
{
	float den = 0;

	if (density < cartoonThreshold) {
		den = 0;
	}
	else {
		den = 0.5;
	}

	return den;
}

float gaussianize_density(float density, float center, float sigma)
{
	return exp(-pow(abs((density - center) / sigma), 2));
}

void dustyturb_rhov_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize, UnityTexture3D rhovTex, UnitySamplerState volumeSampler, float3 rhoScale, float rhoPower, float velocityScale, float velocityPower, float lightAbsorb, float transmittance, float hitThreshold, float hitDamping, bool cartoonize, float cartoonThreshold, out float3 result)
{
	float density = 0;
    float transmission = 0;
    float finalLight = 0;
	bool stopRay = false;
	bool isowallHit = false;
	float lifetime = 1; // Remains at 1 if never hits isowall, gets reduced each step otherwise
	float3 offset = float3(0.5, 0.5, 0.5);

	for (int i = 0; i < numSteps; i++) {
		
		if (!stopRay) {
			rayOrigin += rayDirection * stepSize;

			// The blue dot position
			float3 samplePos = rayOrigin + offset;
			float4 rgba = SAMPLE_TEXTURE3D(rhovTex, volumeSampler, samplePos);
			float sampledDensity = rgba.r;
			float sampledVelocity = rgba.g;
			
			// Stop raymarch if blocked by intensity wall (hit)
			if (sampledDensity > hitThreshold) {
				isowallHit = true;
			}

			if (cartoonize) {
				sampledDensity = cartoonize_density(sampledDensity, cartoonThreshold);
			}

			sampledDensity = rhoScale * pow(abs(sampledDensity), rhoPower);

			if (!is_within_bounds(rayOrigin)) {
				stopRay = true;
			}

			if (!stopRay) {
				density += sampledDensity;

				// Light based on velocity textures
				float lightTransmission = velocityScale * pow(abs(sampledVelocity), velocityPower);
				
				// The final light value is accumulated based on the current density, global transmittance value and the calculated local light (derived from velocity)
				finalLight += density * transmittance * lightTransmission;

				// Transmittance is reduced each time (with accumulated density & global light absorption param)
				transmittance *= exp(-density * lightAbsorb);
			}

			// Reduce lifetime a bit each step after ray has hit isowall
			if (isowallHit) {
				lifetime = max(0, lifetime - 0.001 * hitDamping);

				if (lifetime == 0) {
					stopRay = true;
				}
			}

		}
		
    }

    transmission = exp(-density);

    result = float3(finalLight, transmission, transmittance);
}

void raymarch_isodamp_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize, UnityTexture3D densityTex, UnitySamplerState volumeSampler, float rhoScale, float rhoPower, float lightAbsorb, float darknessThreshold, float transmittance, float hitThreshold, float hitDamping, bool cartoonize, float cartoonThreshold, out float3 result)
{
	float density = 0;
    float transmission = 0;
    float finalLight = 0;
	bool stopRay = false;
	bool isowallHit = false;
	float lifetime = 1; // Remains at 1 if never hits isowall, gets reduced each step otherwise
	float3 offset = float3(0.5, 0.5, 0.5);

	for (int i = 0; i < numSteps; i++) {
		
		if (!stopRay) {
			rayOrigin += rayDirection * stepSize;

			// The blue dot position
			float3 samplePos = rayOrigin + offset;
			float4 rgba = SAMPLE_TEXTURE3D(densityTex, volumeSampler, samplePos);
			float sampledDensity = rgba.r;
			
			// Stop raymarch if blocked by intensity wall (hit)
			if (sampledDensity > hitThreshold) {
				isowallHit = true;
			}

			if (cartoonize) {
				sampledDensity = cartoonize_density(sampledDensity, cartoonThreshold);
			}

			sampledDensity = rhoScale * pow(abs(sampledDensity), rhoPower);

			if (!is_within_bounds(rayOrigin)) {
				stopRay = true;
			}

			if (!stopRay) {
				density += sampledDensity;

				// Light based on velocity textures
				float lightTransmission = 1;//velocityScale * pow(abs(sampledVelocity), velocityPower);
				
				// Shadow tends to the darkness threshold as lightAccumulation rises
				float shadow = darknessThreshold + lightTransmission * (1.0 - darknessThreshold);

				// The final light value is accumulated based on the current density, global transmittance value and the calculated local light (derived from velocity)
				finalLight += density * transmittance * shadow;

				// Transmittance is reduced each time (with accumulated density & global light absorption param)
				transmittance *= exp(-density * lightAbsorb);
			}

			// Reduce lifetime a bit each step after ray has hit isowall
			if (isowallHit) {
				lifetime = max(0, lifetime - 0.001 * hitDamping);

				if (lifetime == 0) {
					stopRay = true;
				}
			}

		}
		
    }

    transmission = exp(-density);

    result = float3(finalLight, transmission, transmittance);

}

// The Agadir tracer is like an isohit tracer but with several densities used as stop threshold
// cartoonThreshold is automatically assumed below (to get this nice surface effect)
// The difference between the cartoon and stop thresholds is controlled by thickness
void agadir_isohit_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize, UnityTexture3D densityTex, UnitySamplerState volumeSampler, float rhoScale1, float rhoPower1, float rhoScale2, float rhoPower2, float lightAbsorb, float transmittance, float stopThreshold1, float stopThreshold2, float thickness, out float3 result)
{
	float3 offset = float3(0.5, 0.5, 0.5);
	float density1 = 0;
	float density2 = 0;
	float transmittance1 = transmittance;
	float transmittance2 = transmittance;
    float finalLight1 = 0;
    float finalLight2 = 0;
	bool stopRay1 = false;
	bool stopRay2 = false;
	float cartoonThreshold1 = stopThreshold1 - thickness;
	float cartoonThreshold2 = stopThreshold2 - thickness;

	for (int i = 0; i < numSteps; i++) {
		if (!(stopRay1 && stopRay2)) {
			rayOrigin += rayDirection * stepSize;

			float3 samplePos = rayOrigin + offset;
			float4 rgba = SAMPLE_TEXTURE3D(densityTex, volumeSampler, samplePos);
			float sampledDensity = rgba.r;
			
			// Stop raymarch if blocked by intensity wall (hit)
			if (sampledDensity > stopThreshold1) {
				stopRay1 = true;
			}
			if (sampledDensity > stopThreshold2) {
				stopRay2 = true;
			}

			float rho1 = cartoonize_density(sampledDensity, cartoonThreshold1);
			float rho2 = cartoonize_density(sampledDensity, cartoonThreshold2);
			
			rho1 = rhoScale1 * pow(abs(rho1), rhoPower1);
			rho2 = rhoScale2 * pow(abs(rho2), rhoPower2);

			if (!is_within_bounds(rayOrigin)) {
				stopRay1 = true;
				stopRay2 = true;
			}

			if (!stopRay1) {
				density1 += rho1;
				finalLight1 += rho1 * transmittance1;
				transmittance1 *= exp(-density1 * lightAbsorb); // Transmittance is reduced each time (with accumulated density & global light absorption param)
			}

			if (!stopRay2) {
				density2 += rho2;
				finalLight2 += rho2 * transmittance2;
				transmittance2 *= exp(-density2 * lightAbsorb); // Transmittance is reduced each time (with accumulated density & global light absorption param)
			}

		}
    }

	float density = density1 + density2;
	float proportionOf1 = 0;
	if (density > 0) {
		proportionOf1 = density1 / density;
	}
    float transmission = exp(-density);
	float finalLight = finalLight1 + finalLight2;

	result = float3(finalLight, transmission, proportionOf1);

}

void agadir_multirouting_isohit_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize, UnityTexture3D studyTex123, UnityTexture3D studyTex456, UnitySamplerState volumeSampler, float scale1, float power1, float scale2, float power2, float lightAbsorb, float transmittance, float stopThreshold1, float stopThreshold2, float thickness, float xSlice, out float3 result)
{
	float3 offset = float3(0.5, 0.5, 0.5);
	float density1 = 0;
	float density2 = 0;
	float transmittance1 = transmittance;
	float transmittance2 = transmittance;
    float finalLight1 = 0;
    float finalLight2 = 0;
	bool stopRay1 = false;
	bool stopRay2 = false;
	float cartoonThreshold1 = stopThreshold1 - thickness;
	float cartoonThreshold2 = stopThreshold2 - thickness;

	for (int i = 0; i < numSteps; i++) {
		if (!(stopRay1 && stopRay2)) {
			rayOrigin += rayDirection * stepSize;

			float3 samplePos = rayOrigin + offset;
			float4 rgba1 = SAMPLE_TEXTURE3D(studyTex123, volumeSampler, samplePos);
			float4 rgba2 = SAMPLE_TEXTURE3D(studyTex456, volumeSampler, samplePos);
			float sample1 = rgba1.r;
			float sample2 = rgba1.g;
			float sample3 = rgba1.b;
			float sample4 = rgba2.r;
			float sample5 = rgba2.g;
			float sample6 = rgba2.b;

			float chosenSample1 = sample2 - sample3;
			float chosenSample2 = sample6 - sample3;
			
			// Slice
			if (rayOrigin.x > xSlice) {
				chosenSample1 = 0;
				chosenSample2 = 0;
			}
			// Stop raymarch if blocked by intensity wall (hit)
			if (chosenSample1 > stopThreshold1) {
				stopRay1 = true;
			}
			if (chosenSample2 > stopThreshold2) {
				stopRay2 = true;
			}

			float rho1 = cartoonize_density(chosenSample1, cartoonThreshold1);
			float rho2 = cartoonize_density(chosenSample2, cartoonThreshold2);
			
			rho1 = scale1 * pow(abs(rho1), power1);
			rho2 = scale2 * pow(abs(rho2), power2);

			if (!is_within_bounds(rayOrigin)) {
				stopRay1 = true;
				stopRay2 = true;
			}

			if (!stopRay1) {
				density1 += rho1;
				finalLight1 += rho1 * transmittance1;
				transmittance1 *= exp(-density1 * lightAbsorb); // Transmittance is reduced each time (with accumulated density & global light absorption param)
			}

			if (!stopRay2) {
				density2 += rho2;
				finalLight2 += rho2 * transmittance2;
				transmittance2 *= exp(-density2 * lightAbsorb); // Transmittance is reduced each time (with accumulated density & global light absorption param)
			}

		}
    }

	float density = density1 + density2;
	float proportionOf1 = 0;
	if (density > 0) {
		proportionOf1 = density1 / density;
	}
    float transmission = exp(-density);
	float finalLight = finalLight1 + finalLight2;

	result = float3(finalLight, transmission, proportionOf1);

}

void gaussian_adagir_youngdisk_study_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize, UnityTexture3D studyTex123, UnityTexture3D studyTex456, UnitySamplerState volumeSampler, float scale1, float power1, float scale2, float power2, float lightAbsorb, float transmittance, float center1, float sigma1, float center2, float sigma2, float xSlice, out float3 result)
{
	float3 offset = float3(0.5, 0.5, 0.5);
	float density1 = 0;
	float density2 = 0;
	float transmittance1 = transmittance;
	float transmittance2 = transmittance;
    float finalLight1 = 0;
    float finalLight2 = 0;
	bool stopRay1 = false;
	bool stopRay2 = false;

	for (int i = 0; i < numSteps; i++) {
		if (!(stopRay1 && stopRay2)) {
			rayOrigin += rayDirection * stepSize;

			float3 samplePos = rayOrigin + offset;
			float4 rgba1 = SAMPLE_TEXTURE3D(studyTex123, volumeSampler, samplePos);
			float4 rgba2 = SAMPLE_TEXTURE3D(studyTex456, volumeSampler, samplePos);
			float sample1 = rgba1.r;
			float sample2 = rgba1.g;
			float sample3 = rgba1.b;
			float sample4 = rgba2.r;
			float sample5 = rgba2.g;
			float sample6 = rgba2.b;

			float chosenSample1 = sample2 - sample3;
			float chosenSample2 = sample5;
			
			// Slice
			if (rayOrigin.x > xSlice) {
				chosenSample1 = 0;
				chosenSample2 = 0;
			}

			float rho1 = gaussianize_density(chosenSample1, center1, sigma1);
			float rho2 = gaussianize_density(chosenSample2, center2, sigma2);
			
			rho1 = scale1 * pow(abs(rho1), power1);
			rho2 = scale2 * pow(abs(rho2), power2);

			if (!is_within_bounds(rayOrigin)) {
				stopRay1 = true;
				stopRay2 = true;
			}

			if (!stopRay1) {
				density1 += rho1;
				finalLight1 += rho1 * transmittance1;
				transmittance1 *= exp(-density1 * lightAbsorb); // Transmittance is reduced each time (with accumulated density & global light absorption param)
			}

			if (!stopRay2) {
				density2 += rho2;
				finalLight2 += rho2 * transmittance2;
				transmittance2 *= exp(-density2 * lightAbsorb); // Transmittance is reduced each time (with accumulated density & global light absorption param)
			}

		}
    }

	float density = density1 + density2;
	float proportionOf1 = 0;
	if (density > 0) {
		proportionOf1 = density1 / density;
	}
    float transmission = exp(-density);
	float finalLight = finalLight1 + finalLight2;

	result = float3(finalLight, transmission, proportionOf1);

}

void gaussian_adagir_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize, bool multiSampling, bool extremeSampling, float multiSamplingRad, float polishDistance, UnityTexture3D rhoTex, UnitySamplerState volumeSampler, float scale1, float power1, float scale2, float power2, float lightAbsorb, float transmittance, float center1, float sigma1, float center2, float sigma2, out float3 result)
{
	float3 offset = float3(0.5, 0.5, 0.5);
	float density1 = 0;
	float density2 = 0;
	float transmittance1 = transmittance;
	float transmittance2 = transmittance;
    float finalLight1 = 0;
    float finalLight2 = 0;
	bool stopRay1 = false;
	bool stopRay2 = false;
	
	// Multi sampling
	float extraPos1 = multiSamplingRad * float3(1, 0, 0);
	float extraPos2 = multiSamplingRad * float3(-1, 0, 0);
	float extraPos3 = multiSamplingRad * float3(0, 1, 0);
	float extraPos4 = multiSamplingRad * float3(0, -1, 0);
	float extraPos5 = multiSamplingRad * float3(0, 0, 1);
	float extraPos6 = multiSamplingRad * float3(0, 0, -1);

	// Extreme multi sampling
	float extraPos11 = multiSamplingRad * float3(1, 1, 1);
	float extraPos12 = multiSamplingRad * float3(-1, 1, 1);
	float extraPos13 = multiSamplingRad * float3(1, -1, 1);
	float extraPos14 = multiSamplingRad * float3(-1, -1, 1);
	float extraPos15 = multiSamplingRad * float3(1, 1, -1);
	float extraPos16 = multiSamplingRad * float3(-1, 1, -1);
	float extraPos17 = multiSamplingRad * float3(1, -1, -1);
	float extraPos18 = multiSamplingRad * float3(-1, -1, -1);

	if (extremeSampling) {
		extraPos1 *= 2;
		extraPos2 *= 2;
		extraPos3 *= 2;
		extraPos4 *= 2;
		extraPos5 *= 2;
		extraPos6 *= 2;
	}
	
	for (int i = 0; i < numSteps; i++) {
		if (!(stopRay1 && stopRay2)) {
			rayOrigin += rayDirection * stepSize;

			float3 samplePos = rayOrigin + offset;
			float4 rgba = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos);
			float sampledRho = 0;

			if (multiSampling) {
				float4 rgba1 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos1);
				float4 rgba2 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos2);
				float4 rgba3 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos3);
				float4 rgba4 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos4);
				float4 rgba5 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos5);
				float4 rgba6 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos6);
				sampledRho = 0.1 * (1 * rgba.r + 1.5 * rgba1.r + 1.5 * rgba2.r + 1.5 * rgba3.r + 1.5 * rgba4.r + 1.5 * rgba5.r + 1.5 * rgba6.r);
				
				if (extremeSampling) {
					float4 rgba11 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos11);
					float4 rgba12 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos12);
					float4 rgba13 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos13);
					float4 rgba14 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos14);
					float4 rgba15 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos15);
					float4 rgba16 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos16);
					float4 rgba17 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos17);
					float4 rgba18 = SAMPLE_TEXTURE3D(rhoTex, volumeSampler, samplePos + extraPos18);

					sampledRho = 0.05556 * (1 * rgba.r + 1.5 * (rgba1.r + rgba2.r + rgba3.r + rgba4.r + rgba5.r + rgba6.r) + 1 * (rgba11.r + rgba12.r + rgba13.r + rgba14.r + rgba15.r + rgba16.r + rgba17.r + rgba18.r));
				}
				
			} else {
				sampledRho = rgba.r;
			}

			float rho1 = gaussianize_density(sampledRho, center1, sigma1);
			float rho2 = gaussianize_density(sampledRho, center2, sigma2);
			
			rho1 = scale1 * pow(abs(rho1), power1);
			rho2 = scale2 * pow(abs(rho2), power2);

			// Border damping (polish)
			rho1 *= polish_factor(rayOrigin, polishDistance);
			rho2 *= polish_factor(rayOrigin, polishDistance);

			if (!is_within_bounds(rayOrigin)) {
				stopRay1 = true;
				stopRay2 = true;
			}

			if (!stopRay1) {
				density1 += rho1;
				finalLight1 += rho1 * transmittance1;
				transmittance1 *= exp(-density1 * lightAbsorb); // Transmittance is reduced each time (with accumulated density & global light absorption param)
			}

			if (!stopRay2) {
				density2 += rho2;
				finalLight2 += rho2 * transmittance2;
				transmittance2 *= exp(-density2 * lightAbsorb); // Transmittance is reduced each time (with accumulated density & global light absorption param)
			}

		}
    }

	float density = density1 + density2;
	float proportionOf1 = 0;
	if (density > 0) {
		proportionOf1 = density1 / density;
	}
    float transmission = exp(-density);
	float finalLight = finalLight1 + finalLight2;

	result = float3(finalLight, transmission, proportionOf1);

}

void raymarchisohit_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize, float densityScale, UnityTexture3D volumeTex, UnitySamplerState volumeSampler, float3 offset, float numLightSteps, float3 lightPos, float lightAbsorb, float darknessThreshold, float transmittance, float stopThreshold, bool cartoonize, float cartoonThreshold, out float3 result)
{
	float density = 0;
    float transmission = 0;
    float lightAccumulation = 0;
    float finalLight = 0;
	bool stopRay = false;

	for (int i = 0; i < numSteps; i++) {
		
		if (!stopRay) {
			rayOrigin += rayDirection * stepSize;

			float3 samplePos = rayOrigin + offset;
			float sampledDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, samplePos).r;

			// Stop raymarch if blocked by intensity wall (hit)
			if (sampledDensity > stopThreshold) {
				stopRay = true;
			}
			if (!is_within_bounds(rayOrigin)) {
				stopRay = true;
			}

			if (cartoonize) {
				sampledDensity = cartoonize_density(sampledDensity, cartoonThreshold);
			}

			if (!stopRay) {
				density += sampledDensity * densityScale;
			}

			// Light loop
			float3 lightRayOrigin = samplePos;
			float3 lightDiff = lightPos - lightRayOrigin;
			float3 lightStep = lightDiff / numLightSteps;
			float lightScaleAtEachStep = 1 / numLightSteps; // Catches more light per step if low step count

			for (int j = 0; j < numLightSteps; j++)	{
				if (!stopRay) {
					// Marching towards light point origin
					lightRayOrigin += lightStep;
					
					float lightDensity = 0;
					
					// Distance to light point origin
					// float dis = distance(lightRayOrigin, lightPos);
					
					lightDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, lightRayOrigin).r;
					
					// The accumulated density from samplePos to the light - the higher this value the less light reaches samplePos (== lightRayOrigin)
					lightAccumulation += lightDensity * lightScaleAtEachStep;
				}
			}

			// The amount of light received along the ray from param rayOrigin in the direction rayDirection
			float lightTransmission = exp(-lightAccumulation);
			
			// Shadow tends to the darkness threshold as lightAccumulation rises
			float shadow = darknessThreshold + lightTransmission * (1.0 - darknessThreshold);
			
			// The final light value is accumulated based on the current density, transmittance value and the calculated shadow value 
			finalLight += density * transmittance * shadow;
			
			// Initially a param its value is updated at each step by lightAbsorb, this sets the light lost by scattering
			transmittance *= exp(-density * lightAbsorb);

		}
		
    }

    transmission = exp(-density);

    result = float3(finalLight, transmission, transmittance);
}

// Intoducing hitDamping, a reduction of ray range once it hits an isodense wall (density value defined by stopThreshold)
void raymarch_coupled_isodamp_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize, UnityTexture3D densityTex, UnityTexture3D velocityTex1, UnityTexture3D velocityTex2, UnityTexture3D velocityTex3, UnitySamplerState volumeSampler, float3 offset, float rhoScale, float rhoPower, float velocityScale, float velocityPower, float lightAbsorb, float darknessThreshold, float transmittance, float stopThreshold, float isohitDamping, bool cartoonize, float cartoonThreshold, out float3 result)
{
	float density = 0;
    float transmission = 0;
    float lightAccumulation = 0;
    float finalLight = 0;
	bool stopRay = false;
	bool isowallHit = false;
	float lifetime = 1; // Remains at 1 if never hits isowall, gets reduced each step otherwise

	for (int i = 0; i < numSteps; i++) {
		
		if (!stopRay) {
			rayOrigin += rayDirection * stepSize;

			// The blue dot position
			float3 samplePos = rayOrigin + offset;
			float sampledDensity = SAMPLE_TEXTURE3D(densityTex, volumeSampler, samplePos).r;
			
			// Stop raymarch if blocked by intensity wall (hit)
			if (sampledDensity > stopThreshold) {
				isowallHit = true;
			}

			if (cartoonize) {
				sampledDensity = cartoonize_density(sampledDensity, cartoonThreshold);
			}

			sampledDensity = rhoScale * pow(abs(sampledDensity), rhoPower);

			if (!is_within_bounds(rayOrigin)) {
				stopRay = true;
			}

			if (!stopRay) {
				density += sampledDensity;

				// Light based on velocity textures
				float vx = SAMPLE_TEXTURE3D(velocityTex1, volumeSampler, samplePos).r - 0.5;
				float vy = SAMPLE_TEXTURE3D(velocityTex2, volumeSampler, samplePos).r - 0.5;
				float vz = SAMPLE_TEXTURE3D(velocityTex3, volumeSampler, samplePos).r - 0.5;
				float v = sqrt(vx * vx + vy * vy + vz * vz);

				float lightTransmission = velocityScale * pow(abs(v), velocityPower);
				
				// Shadow tends to the darkness threshold as lightAccumulation rises
				float shadow = darknessThreshold + lightTransmission * (1.0 - darknessThreshold);
				
				// The final light value is accumulated based on the current density, transmittance value and the calculated shadow value
				finalLight += density * transmittance * shadow;

				// Initially a param its value is updated at each step by lightAbsorb, this sets the light lost by scattering
				transmittance *= exp(-density * lightAbsorb);
			}

			// Reduce lifetime a bit each step after ray has hit isowall
			if (isowallHit) {
				lifetime = max(0, lifetime - 0.001 * isohitDamping);

				if (lifetime == 0) {
					stopRay = true;
				}
			}

		}
		
    }

    transmission = exp(-density);

    result = float3(finalLight, transmission, transmittance);
}

void raymarchcoupled_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize, UnityTexture3D densityTex, UnityTexture3D velocityTex1, UnityTexture3D velocityTex2, UnityTexture3D velocityTex3, UnitySamplerState volumeSampler, float3 offset, float rhoScale, float rhoPower, float velocityScale, float velocityPower, float lightAbsorb, float darknessThreshold, float transmittance, float stopThreshold, bool cartoonize, float cartoonThreshold, out float3 result)
{
	float density = 0;
    float transmission = 0;
    float lightAccumulation = 0;
    float finalLight = 0;
	bool stopRay = false;

	for (int i = 0; i < numSteps; i++)
    {
		
		if (!stopRay) {
			rayOrigin += rayDirection * stepSize;

			// The blue dot position
			float3 samplePos = rayOrigin + offset;
			float sampledDensity = SAMPLE_TEXTURE3D(densityTex, volumeSampler, samplePos).r;
			
			// Stop raymarch if blocked by intensity wall (hit)
			if (sampledDensity > stopThreshold) {
				stopRay = true;
			}

			if (cartoonize) {
				sampledDensity = cartoonize_density(sampledDensity, cartoonThreshold);
			}

			sampledDensity = rhoScale * pow(abs(sampledDensity), rhoPower);

			if (!is_within_bounds(rayOrigin)) {
				stopRay = true;
			}

			if (!stopRay) {
				density += sampledDensity;

				// Light based on velocity textures
				float vx = SAMPLE_TEXTURE3D(velocityTex1, volumeSampler, samplePos).r - 0.5;
				float vy = SAMPLE_TEXTURE3D(velocityTex2, volumeSampler, samplePos).r - 0.5;
				float vz = SAMPLE_TEXTURE3D(velocityTex3, volumeSampler, samplePos).r - 0.5;
				float v = sqrt(vx * vx + vy * vy + vz * vz);

				float lightTransmission = velocityScale * pow(abs(v), velocityPower);
				
				// Shadow tends to the darkness threshold as lightAccumulation rises
				float shadow = darknessThreshold + lightTransmission * (1.0 - darknessThreshold);
				
				// The final light value is accumulated based on the current density, transmittance value and the calculated shadow value 
				finalLight += density * transmittance * shadow;

				// Initially a param its value is updated at each step by lightAbsorb, this sets the light lost by scattering
				transmittance *= exp(-density * lightAbsorb);
			}

		}
		
    }

    transmission = exp(-density);

    result = float3(finalLight, transmission, transmittance);
}

void raymarchpoint_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize,
                    float densityScale, UnityTexture3D volumeTex, UnitySamplerState volumeSampler,
                    float3 offset, float numLightSteps, float lightStepSize, float3 lightPos,
                    float lightAbsorb, float darknessThreshold, float transmittance, out float3 result)
{
    float density = 0;
    float transmission = 0;
    float lightAccumulation = 0;
    float finalLight = 0;

    for (int i = 0; i < numSteps; i++)
    {
        rayOrigin += rayDirection * stepSize;

		// The blue dot position
        float3 samplePos = rayOrigin + offset;
        float sampledDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, samplePos).r;
        density += sampledDensity * densityScale;

		// Light loop
        float3 lightRayOrigin = samplePos;
        float3 lightDir = lightPos - samplePos;
        float distToLight = distance(samplePos, lightPos);
		
        for (int j = 0; j < numLightSteps; j++)
        {
			// Marching towards light point origin
            lightRayOrigin += lightDir * lightStepSize;
			
            float lightDensity = 0;
			
			// Distance to light point origin
            float dis = distance(lightRayOrigin, lightPos);
			
			// If we went past the light point, don't accumulate light (leave value at 0)
			// Otherwise yeah, sample the cloud
            if (dis < distToLight)
            {
                lightDensity = lightDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, lightRayOrigin).r;
            }
			
			// The accumulated density from samplePos to the light - the higher this value the less light reaches samplePos
            lightAccumulation += lightDensity;
        }

		// The amount of light received along the ray from param rayOrigin in the direction rayDirection
        float lightTransmission = exp(-lightAccumulation);
		
		// Shadow tends to the darkness threshold as lightAccumulation rises
        float shadow = darknessThreshold + lightTransmission * (1.0 - darknessThreshold);
		
		// The final light value is accumulated based on the current density, transmittance value and the calculated shadow value 
        finalLight += density * transmittance * shadow;
		
		// Initially a param its value is updated at each step by lightAbsorb, this sets the light lost by scattering
        transmittance *= exp(-density * lightAbsorb);
		
    }

    transmission = exp(-density);

    result = float3(finalLight, transmission, transmittance);
}

void raymarchv1_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize,
                      float densityScale, float4 Sphere, out float result)
{
	float density = 0;
	
	for (int i = 0; i < numSteps; i++) {
		rayOrigin += rayDirection * stepSize;
					
		// Calculate density
		float sphereDist = distance(rayOrigin, Sphere.xyz);

		if (sphereDist < Sphere.w) {
			density += 0.1;
        }
		
	}

	result = density * densityScale;
}

void raymarchv2_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize,
                      float densityScale, UnityTexture3D volumeTex, UnitySamplerState volumeSampler,
                      float3 offset, out float result)
{
	float density = 0;
	float transmission = 0;
	
	for (int i = 0; i < numSteps; i++) {
		rayOrigin += rayDirection * stepSize;
					
		// Calculate density
		float sampledDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, rayOrigin + offset).r;
		density += sampledDensity;
	}

	result = density * densityScale;
}

void raymarchv3_float(float3 rayOrigin, float3 rayDirection, float numSteps, float stepSize,
                      float densityScale, UnityTexture3D volumeTex, UnitySamplerState volumeSampler,
                      float3 offset, float numLightSteps, float lightStepSize, float3 lightPosition,
                      out float result)
{
	float density = 0;
	float lightAccumulation = 0;
	//offset -= SHADERGRAPH_OBJECT_POSITION;
	
	for (int i = 0; i < numSteps; i++) {
		rayOrigin += rayDirection * stepSize;
		float3 samplePos = rayOrigin + offset;		
		
		// Calculate density
		float sampledDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, samplePos).r;
		density += sampledDensity;

		float3 lightRayOrigin = samplePos;
		float3 lightDir = samplePos - lightPosition;

		for (int j = 0; j < numLightSteps; j++) {
			lightRayOrigin += lightDir * lightStepSize;
			float lightDensity = SAMPLE_TEXTURE3D(volumeTex, volumeSampler, lightRayOrigin).r;
			lightAccumulation += lightDensity;
		}	
	}

	result = density * densityScale;
}
