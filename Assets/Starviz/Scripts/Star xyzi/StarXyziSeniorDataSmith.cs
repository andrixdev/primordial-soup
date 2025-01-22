/**
 * ANDRIX® 2020-2025
 *
 * This script reads simple position XYZ data with intensity channel
 * It generates 2D textures for interpretation in a Visual Effect Graph ✨
 * Tested up to 6M points, can theoretically go up to 268M but it hurts machines 😑
 */

using System;
using System.Globalization;
using UnityEngine;
using UnityEngine.VFX;
using UnityEngine.Windows;
using Unity.Mathematics;

public class StarXyziSeniorDataSmith : MonoBehaviour
{
	public TextAsset textAsset; // test-aa.txt

	// RGBAFloat data works well for values in [0, 1] (not [-1, 1] btw) so we need some wee data pre-scaling

	// Rescaling for xyz positions ([0, 4] -> [0, 1.0f])
	public float xyzMin = 0.0f;
	public float xyzMax = 4.0f;

	// Rescaling for intensity ([-100, 0] -> [0, 1.0f])
	public float intensityMin = -100.0f;
	public float intensityMax = 0.0f;

	[HideInInspector] // Important! (super long data, you don't want it in the Editor)
	public StarXyziData starXyziData;

	[HideInInspector] // Important! (super long data, you don't want it in the Editor)
    public Texture2D texture1; // Will store (x, y, z, ⌀) in RGBA
	[HideInInspector]
    public Texture2D texture2; // Will store (intensity, ⌀, ⌀, ⌀) in RGBA
	[HideInInspector]
	public Texture2D texture3; // Will store (⌀, ⌀, ⌀, ⌀)
	
	private float timeStart;
	
	void OnEnable()
    {
		// Log info about GPU capabilities
		Debug.Log("<color=#009090ff>[Senior Data Smith] This machine's maximal texture size is " + SystemInfo.maxTextureSize + ". RoaAAAaaarrrh! Max of Unity: 16384.</color>"); // Docs 2022.3 SystemInfo.maxTextureSize -> « Unity only supports textures up to a size of 16384, even if maxTextureSize returns a larger size. »

        // Read le file
		Read();
		
		// Build le textures
		int quarticRoot = 50; // Keep it a little greater than the quartic root of the number of items, max 127, recommended max 50 (6.250.000 points)
        CreateTextures(quarticRoot);

		// Save textures in PNG
		SaveTextures();
    }

    void Start()
    {
		
    }

	public void Read()
	{
		timeStart = Time.realtimeSinceStartup;

		// Split lines
		string[] lines = textAsset.text.Split('\n');

		/**
		 * Line format:
		 * 50 10 340 109
		 * x y z intensity
		 *
		 * (x, y, z) Position
		 * intensity Intensity on that position
		 */
		starXyziData = new StarXyziData(lines.Length);
		for (int i = 0; i < lines.Length; i++)
		{
			string[] fields = lines[i].Split(' ');
			float x = math.remap(xyzMin, xyzMax, 0, 1.0f, Convert.ToSingle(fields[0], CultureInfo.InvariantCulture));
			float y = math.remap(xyzMin, xyzMax, 0, 1.0f, Convert.ToSingle(fields[1], CultureInfo.InvariantCulture));
			float z = math.remap(xyzMin, xyzMax, 0, 1.0f, Convert.ToSingle(fields[2], CultureInfo.InvariantCulture));
			float intensity = math.remap(intensityMin, intensityMax, 0, 1.0f, Convert.ToSingle(fields[3], CultureInfo.InvariantCulture));
			
			StarXyziBit xyzi = new StarXyziBit();

			xyzi.x = x;
			xyzi.y = y;
			xyzi.z = z;
			xyzi.intensity = intensity;

			starXyziData.data[i] = xyzi;
		}

		// Success message
		Debug.Log("<color=#009090ff>[Senior Data Smith] " + lines.Length + " lines of xyzi data were parsed 💪</color>");

		// Random data log
		int testIndex = Convert.ToInt32(Math.Floor(lines.Length * 0.75));
		StarXyziBit testXyzi = starXyziData.data[testIndex];
		Debug.Log("<color=#009090ff>[Senior Data Smith] Logging xyzi data bit for index " + testIndex +  ": x = " + testXyzi.x + ", y = " + testXyzi.y + ", z = " + testXyzi.z + ", intensity = " + testXyzi.intensity + "</color>");
		
		// Log time taken
		Debug.Log("<color=#009090ff>[Senior Data Smith] Forged data in " + (Time.realtimeSinceStartup - timeStart) + " seconds 🔨</color>");
	}

	void CreateTextures(int size)
	{
		timeStart = Time.realtimeSinceStartup;

		Color[] colorArray1 = new Color[size * size * size * size];
		Color[] colorArray2 = new Color[size * size * size * size];
		Color[] colorArray3 = new Color[size * size * size * size];
		
		// RGBAHalf is sufficient as we're using floats to parse data and not doubles, RGBAFloat might be needed if we parse to doubles
		texture1 = new Texture2D(size * size, size * size, TextureFormat.RGBAHalf, true); 
		texture2 = new Texture2D(size * size, size * size, TextureFormat.RGBAHalf, true);
		texture3 = new Texture2D(size * size, size * size, TextureFormat.RGBAHalf, true);
		
		// Single loop to inject data array values in textures
		float r = 1.0f / (size - 1.0f);
        for (int x = 0; x < size; x++)
		{
            for (int y = 0; y < size; y++)
			{
                for (int z = 0; z < size * size; z++)
				{
					int index = x + (y * size) + (z * size * size);
					Color c1 = new Color(0, 0, 0, 0);
					Color c2 = new Color(0, 0, 0, 0);
					Color c3 = new Color(0, 0, 0, 0);
					
					StarXyziBit xyzi;

					if (index < starXyziData.data.Length)
					{
						xyzi = starXyziData.data[index];
					}
					else
					{
						xyzi = new StarXyziBit();
						xyzi.x = 0;
						xyzi.y = 0;
						xyzi.z = 0;
						xyzi.intensity = 0;
					}

					// Shape color information for textures
					c1 = new Color(xyzi.x, xyzi.y, xyzi.z, 0);
					c2 = new Color(xyzi.intensity, 0, 0, 0);
					c3 = new Color(0, 0, 0, 0);
					
                    colorArray1[index] = c1;
                    colorArray2[index] = c2;
                    colorArray3[index] = c3;
                }
            }
        }
		
		// Inject in textures
		texture1.SetPixels(colorArray1);
		texture2.SetPixels(colorArray2);
		texture3.SetPixels(colorArray3);
		texture1.Apply();
		texture2.Apply();
		texture3.Apply();

		// Log time taken
		Debug.Log("<color=#009090ff>[Senior Data Smith] Generated textures in " + (Time.realtimeSinceStartup - timeStart) + " seconds 👌</color>");
	}

	private void SaveTextures()
	{
		float time = Time.realtimeSinceStartup;
		
		byte[] bytes1 = texture1.EncodeToPNG();//ImageConversion.EncodeToPNG(texture1);
		byte[] bytes2 = texture2.EncodeToPNG();
		//byte[] bytes3 = texture3.EncodeToPNG();

		System.IO.File.WriteAllBytes(Application.dataPath + "/Starviz/Data/texture1.png", bytes1);
		System.IO.File.WriteAllBytes(Application.dataPath + "/Starviz/Data/texture2.png", bytes2);
		//System.IO.File.WriteAllBytes(Application.dataPath + "/Starviz/Data/texture3.png", bytes3);
	
		Debug.Log("<color=#ff33ccff>[Senior Data Smith] Encoded and saved textures in " + (Time.realtimeSinceStartup - time) + " seconds 👌</color>");
			
	}
}
