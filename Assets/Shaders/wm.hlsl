void wm(float3 position, out float4 result)
{
	float r = 0;

	for (int i = 0; i < 50; i++)
	{
		r += position.x / 100;
	}
	result = float4(r, 0.5, 0, 1);
}

// Pseudo-random hash function to replace np.random.uniform
// Generates a stable float between 0.0 and 1.0 based on m and n
float Hash21(float2 p) {
	
	float dotdot = dot(p, float2(12.9898, 78.233));
    return frac(sin(dotdot) * 43758.5453123);
	

	return 1;
}

// 3D Weierstrass-Mandelbrot Function
// pos   : 2D spatial coordinates (x, y)
// D     : Fractal dimension (typically 2.0 to 3.0)
// G     : Amplitude roughness coefficient
// L     : Transverse width of the profile
// gamma : Frequency scaling factor (typically > 1.0)
// M     : Number of ridges (azimuthal angles)
// n_max : Upper cutoff frequency index

float4 DGLgamma(float D, float G, float L, float gamma)
{
	return float4(D, G, L, gamma);
}
float WeierstrassMandelbrot3D(float2 pos, float4 DGLgamma, int M, int n_max) {

	float pi = 3.14159265359;
    float two_pi = 6.28318530718;

	float D = DGLgamma.x;
	float G = DGLgamma.y;
	float L = DGLgamma.z;
	float gamma = DGLgamma.w;

    // Precompute global amplitude A
    // Note: M must be > 0 to avoid division by zero
    float A = L * abs(pow(G / L, D - 2.0)) * sqrt(log(gamma) / (float)M);
    
    float z = 0.0;

    // Loop over azimuthal angles (ridges)
    for (int m = 1; m <= M; ++m) {
		
        // Calculate the angle for this ridge
        float alpha_m = pi * (float)m / (float)M;
        
        // Optimized projection: equivalent to r * cos(theta_m)
        float proj = pos.x * cos(alpha_m) + pos.y * sin(alpha_m);

        // Loop over frequencies
        for (int n = 0; n <= n_max; ++n) {
            // Generate deterministic pseudo-random phase in [0, 2*PI]
			float2 mn = float2((float)m, (float)n);
            float phi_mn = Hash21(mn) * two_pi;
            
            float gamma_n = abs(pow(gamma, (float)n));
            
            // Calculate the main term
            float term = cos(phi_mn) - cos(two_pi * gamma_n * proj / L + phi_mn);
            
            // Accumulate height
            z += abs(pow(gamma, (D - 3.0) * (float)n)) * term;
        }
		
    }

    return A * z;
}