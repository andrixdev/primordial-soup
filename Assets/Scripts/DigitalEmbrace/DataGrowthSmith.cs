/**
 * Alex Andrix © 2020-2024
 * This script reads segment "Growth" data from Alex Andrix visual object inspired by creation Unexplored Space Eaters 3D
 * It generates 2D textures for interpretation in a Visual Effect Graph
 * Works up to 2M points (limited by max texture width)
 */

using System;
using System.Globalization;
using UnityEngine;
using UnityEngine.VFX;
using UnityEngine.Windows;

public class DataGrowthSmith : MonoBehaviour
{
	public TextAsset textAsset; // test-aa.txt
	// RGBAFloat data works well for values in [-1, 1] so we need some wee data pre-scaling
	private float xyzScale = 0.0001f; // Rescaling for xyz positions ([0, 10000] -> [0, 1.0f])
	private float idScale = 0.000001f; // Rescaling for fiber ID ([0, 1 000 000] -> [0, 1.0f])
	private float ageScale = 0.001f; // Rescaling for fiber length ([0, 1000] -> [0, 1.0f])

	[HideInInspector] // Important! (super long data, you don't want it in the Editor)
	public GrowthData growthData;

	[HideInInspector] // Important! (super long data, you don't want it in the Editor)
    public Texture2D texture1; // Will store (x1, y1, z1, ⌀) in RGBA
	[HideInInspector]
    public Texture2D texture2; // Will store (x2, y2, z2, ⌀) in RGBA
	[HideInInspector]
	public Texture2D texture3; // Will store (id, age, ⌀, ⌀)
	
	private float timeStart;
	
	void OnEnable()
    {
        // Read le file
		ReadFile();
		
		// Build le textures
		int cubicRoot = 110; // Keep it a little greater than the cubic root of the number of items, max 126
        CreateTextures(cubicRoot);
    }

    void Start()
    {
		
    }

	public void ReadFile()
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
		growthData = new GrowthData(lines.Length);
		for (int i = 0; i < lines.Length; i++)
		{
			string[] fields = lines[i].Split(' ');
			float x1 = xyzScale * Convert.ToSingle(fields[0], CultureInfo.InvariantCulture);
			float y1 = xyzScale * Convert.ToSingle(fields[1], CultureInfo.InvariantCulture);
			float z1 = xyzScale * Convert.ToSingle(fields[2], CultureInfo.InvariantCulture);
			float x2 = xyzScale * Convert.ToSingle(fields[3], CultureInfo.InvariantCulture);
			float y2 = xyzScale * Convert.ToSingle(fields[4], CultureInfo.InvariantCulture);
			float z2 = xyzScale * Convert.ToSingle(fields[5], CultureInfo.InvariantCulture);
			//float someFlag = someFlagScale * Convert.ToSingle(fields[6], CultureInfo.InvariantCulture);
			float id = idScale * Convert.ToSingle(fields[6], CultureInfo.InvariantCulture);
			float age = ageScale * Convert.ToSingle(fields[7], CultureInfo.InvariantCulture);

			GrowthBit gb = new GrowthBit();

			gb.x1 = x1;
			gb.y1 = y1;
			gb.z1 = z1;
			gb.x2 = x2;
			gb.y2 = y2;
			gb.z2 = z2;
			gb.id = id;
			gb.age = age;

			growthData.data[i] = gb;
		}

		// Success message
		Debug.Log("<color=teal>" + lines.Length + " lines of Growth data were parsed.</color>");

		// Random data log
		int testIndex = Convert.ToInt32(Math.Floor(lines.Length * 0.75));
		GrowthBit testGb = growthData.data[testIndex];
		Debug.Log("<color=teal>Logging Growth bit data for index " + testIndex +  ": x1 = " + testGb.x1 + ", y1 = " + testGb.y1 + ", z1 = " + testGb.z1 + ", x2 = " + testGb.x2 + ", y2 = " + testGb.y2 + ", z2 = " + testGb.z2 + ", id = " + testGb.id + ", age = " + testGb.age + "</color>");
		
		// Log time taken
		Debug.Log("<color=teal>DataGrowthSmith forged data in " + (Time.realtimeSinceStartup - timeStart) + " seconds.</color>");
	}

	void CreateTextures(int size)
	{
		timeStart = Time.realtimeSinceStartup;

		Color[] colorArray1 = new Color[size * size * size];
		Color[] colorArray2 = new Color[size * size * size];
		Color[] colorArray3 = new Color[size * size * size];
		
		// RGBAHalf is sufficient as we're using floats to parse data and not doubles, RGBAFloat might be needed if we parse to doubles
		texture1 = new Texture2D(size * size, size, TextureFormat.RGBAHalf, true); 
		texture2 = new Texture2D(size * size, size, TextureFormat.RGBAHalf, true);
		texture3 = new Texture2D(size * size, size, TextureFormat.RGBAHalf, true);
		
		// Single loop to inject data array values in textures
		float r = 1.0f / (size - 1.0f);
        for (int x = 0; x < size; x++)
		{
            for (int y = 0; y < size; y++)
			{
                for (int z = 0; z < size; z++)
				{
					int index = x + (y * size) + (z * size * size);
					Color c1 = new Color(0, 0, 0, 0);
					Color c2 = new Color(0, 0, 0, 0);
					Color c3 = new Color(0, 0, 0, 0);
					
					GrowthBit gb;

					if (index < growthData.data.Length)
					{
						gb = growthData.data[index];
					}
					else
					{
						gb = new GrowthBit();
						gb.x1 = 0;
						gb.y1 = 0;
						gb.z1 = 0;
						gb.x2 = 0;
						gb.y2 = 0;
						gb.z2 = 0;
						gb.id = 0;
						gb.age = 0;
					}

					// Shape color information for textures
					c1 = new Color(gb.x1, gb.y1, gb.z1, 0);
					c2 = new Color(gb.x2, gb.y2, gb.z2, 0);
					c3 = new Color(gb.id, gb.age, 0, 0);
					
                    colorArray1[index] = c1;
                    colorArray2[index] = c2;
                    colorArray3[index] = c3;
                }
            }
        }
		
		// Log Color values to see if it's float (8 decimals)
		/*
		for (int o = 0; o < 100; o++)
		{
			int testIndex = Convert.ToInt32(Math.Floor(firstEdgesColorArray.Length * UnityEngine.Random.Range(0, 1.0f)));
			Debug.Log("<color=teal>TexMaker2D.cs > sampling random float color data red channel (xA): " + firstEdgesColorArray[testIndex].r + "</color>");
			Debug.Log("<color=teal>TexMaker2D.cs > sampling random float color data red channel (flag): " + secondEdgesColorArray[testIndex].r + "</color>");
		}*/
		
		// Inject in textures
		texture1.SetPixels(colorArray1);
		texture2.SetPixels(colorArray2);
		texture3.SetPixels(colorArray3);
		texture1.Apply();
		texture2.Apply();
		texture3.Apply();

		// Log time taken
		Debug.Log("<color=teal>DataGrowthSmith generated textures in " + (Time.realtimeSinceStartup - timeStart) + " seconds 💪</color>");
	}
}
