/**
 * ANDRIX® 2020-2025
 */

using UnityEngine;

[System.Serializable]
public struct StarXyziData
{
	public StarXyziData(int size)
	{
		data = new StarXyziBit[size];
		title = "Xyzi data from .3D format given by Benoit Commerçon - Processed by Alex Andrix for CRAL";
		version = "1.0";
		date = "2025-01-22";
	}

	public string title;
	public string version;
	public string date;
	public StarXyziBit[] data;
}
