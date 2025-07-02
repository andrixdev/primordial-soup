/**
 * ANDRIX® 2020-2025
 *
 * This script reads position XYZ data and velocities
 * It generates 2D textures for interpretation in a Visual Effect Graph ✨
 * Tested up to 6M points, can theoretically go up to 268M but it hurts machines 😑
 */

using System;
using System.Globalization;
using UnityEngine;
using UnityEngine.VFX;
using UnityEngine.Windows;
using Unity.Mathematics;

public class DEXyznDataSmith : MonoBehaviour
{
	public TextAsset textAsset; // test-aa.txt

	// RGBAFloat data works well for values in [0, 1] (not [-1, 1] btw) so we need some wee data pre-scaling

	// Rescaling for xyz positions ([-1000, 1000] -> [0, 1.0f])
	private float xyzMin = -1000.0f; 
	private float xyzMax = 1000.0f;

	// Rescaling for id ([0, 10000] -> [0, 1.0f])
	private float idMin = 0.0f;
	private float idMax = 10000.0f;
	
	// Rescaling for age/length ([0, 1000] -> [0, 1.0f])
	private float ageMin = 0.0f;
	private float ageMax = 1000.0f;

	[HideInInspector] // Important! (super long data, you don't want it in the Editor)
	public DEXyznData xyznData;

	[HideInInspector] // Important! (super long data, you don't want it in the Editor)
    public Texture2D texture1; // Will store (x1, y1, z1, ⌀) in RGBA
	[HideInInspector]
    public Texture2D texture2; // Will store (x2, y2, z2, ⌀) in RGBA
	[HideInInspector]
	public Texture2D texture3; // Will store (id, age, ⌀, ⌀)
	
	private float timeStart;
	
	void OnEnable()
    {
		// Log info about GPU capabilities
		Debug.Log("<color=#009090ff>[DEXyznDataSmith] This machine's maximal texture size is " + SystemInfo.maxTextureSize + ". RoaAAAaaarrrh! Max of Unity: 16384.</color>"); // Docs 2022.3 SystemInfo.maxTextureSize -> « Unity only supports textures up to a size of 16384, even if maxTextureSize returns a larger size. »

        // Read le file
		Read();
		
		// Build le textures
		int quarticRoot = 30; // Keep it a little greater than the quartic root of the number of items, max 127, recommended max 50 (6.250.000 points)
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
		 * 50 10 340 120 98 224 0 140
		 * x1 y1 z1 x2 y2 z2 id age
		 *
		 * (x1, y1, z1) position in 3D of segment starting point
		 * (x2, y2, z2) position in 3D of segment end point
		 * id ID of the segment
		 * age Age of particle at that segment
		 */
		xyznData = new DEXyznData(lines.Length);
		for (int i = 0; i < lines.Length; i++)
		{
			string[] fields = lines[i].Split(' ');
			float x1 = math.remap(xyzMin, xyzMax, 0.0f, 1.0f, Convert.ToSingle(fields[0], CultureInfo.InvariantCulture));
			float y1 = math.remap(xyzMin, xyzMax, 0.0f, 1.0f, Convert.ToSingle(fields[1], CultureInfo.InvariantCulture));
			float z1 = math.remap(xyzMin, xyzMax, 0.0f, 1.0f, Convert.ToSingle(fields[2], CultureInfo.InvariantCulture));
			
			float x2 = math.remap(xyzMin, xyzMax, 0.0f, 1.0f, Convert.ToSingle(fields[3], CultureInfo.InvariantCulture));
			float y2 = math.remap(xyzMin, xyzMax, 0.0f, 1.0f, Convert.ToSingle(fields[4], CultureInfo.InvariantCulture));
			float z2 = math.remap(xyzMin, xyzMax, 0.0f, 1.0f, Convert.ToSingle(fields[5], CultureInfo.InvariantCulture));
			
			float id = math.remap(idMin, idMax, 0.0f, 1.0f, Convert.ToSingle(fields[6], CultureInfo.InvariantCulture));
			float age = math.remap(ageMin, ageMax, 0.0f, 1.0f, Convert.ToSingle(fields[7], CultureInfo.InvariantCulture));
			
			DEXyznBit xyzn = new DEXyznBit();

			xyzn.x1 = x1;
			xyzn.y1 = y1;
			xyzn.z1 = z1;
			xyzn.x2 = x2;
			xyzn.y2 = y2;
			xyzn.z2 = z2;
			xyzn.id = id;
			xyzn.age = age;

			xyznData.data[i] = xyzn;
		}

		// Success message
		Debug.Log("<color=#009090ff>[DEXyznDataSmith] " + lines.Length + " lines of xyzn data were parsed 💪</color>");

		// Random data log
		int testIndex = Convert.ToInt32(Math.Floor(lines.Length * 0.75));
		DEXyznBit testXyzn = xyznData.data[testIndex];
		Debug.Log("<color=#009090ff>[DEXyznDataSmith] Logging xyzn data bit for index " + testIndex +  ": x1 = " + testXyzn.x1 + ", y1 = " + testXyzn.y1 + ", z1 = " + testXyzn.z1 + ", x2 = " + testXyzn.x2 + ", y2 = " + testXyzn.y2 + ", z2 = " + testXyzn.z2 + ", id = " + testXyzn.id + ", age = " + testXyzn.age + "</color>");
		
		// Log time taken
		Debug.Log("<color=#009090ff>[DEXyznDataSmith] Forged data in " + (Time.realtimeSinceStartup - timeStart) + " seconds 🔨</color>");
	}

	void CreateTextures(int size)
	{
		timeStart = Time.realtimeSinceStartup;

		Color[] colorArray1 = new Color[size * size * size * size];
		Color[] colorArray2 = new Color[size * size * size * size];
		Color[] colorArray3 = new Color[size * size * size * size];
		
		// RGBAHalf is sufficient as we're using floats to parse data and not doubles, RGBAFloat might be needed if we parse to doubles
		texture1 = new Texture2D(size * size, size * size, TextureFormat.RGBAFloat, true); 
		texture2 = new Texture2D(size * size, size * size, TextureFormat.RGBAFloat, true);
		texture3 = new Texture2D(size * size, size * size, TextureFormat.RGBAFloat, true);
		
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
					
					DEXyznBit xyzn;

					if (index < xyznData.data.Length)
					{
						xyzn = xyznData.data[index];
					}
					else
					{
						xyzn = new DEXyznBit();
						xyzn.x1 = 0;
						xyzn.y1 = 0;
						xyzn.z1 = 0;
						xyzn.x2 = 0;
						xyzn.y2 = 0;
						xyzn.z2 = 0;
						xyzn.id = 0;
						xyzn.age = 0;
					}

					// Shape color information for textures
					c1 = new Color(xyzn.x1, xyzn.y1, xyzn.z1, 0);
					c2 = new Color(xyzn.x2, xyzn.y2, xyzn.z2, 0);
					c3 = new Color(xyzn.id, xyzn.age, 0, 0);
					
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
		Debug.Log("<color=#009090ff>[DEXyznDataSmith] Generated textures in " + (Time.realtimeSinceStartup - timeStart) + " seconds 👌</color>");
	}

	private void SaveTextures()
	{
		float time = Time.realtimeSinceStartup;
		
		byte[] bytes1 = texture1.EncodeToPNG();//ImageConversion.EncodeToPNG(texture1);
		byte[] bytes2 = texture2.EncodeToPNG();
		byte[] bytes3 = texture3.EncodeToPNG();

		System.IO.File.WriteAllBytes(Application.dataPath + "/Data/" + textAsset.name + "_texture1.png", bytes1);
		System.IO.File.WriteAllBytes(Application.dataPath + "/Data/" + textAsset.name + "_texture2.png", bytes2);
		System.IO.File.WriteAllBytes(Application.dataPath + "/Data/" + textAsset.name + "_texture3.png", bytes3);
	
		Debug.Log("<color=#ff33ccff>[DEXyznDataSmith] Encoded and saved textures in " + (Time.realtimeSinceStartup - time) + " seconds 👌</color>");
			
	}
}
