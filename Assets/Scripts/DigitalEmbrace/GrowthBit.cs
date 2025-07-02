/**
 * Alex Andrix © 2020-2024
 *
 * Entries
 * x1 y1 z1 x2 y2 z2 id age
 * Min values
 * ~-1500 -1500 -1500 -1500 -1500 -1500 0 0
 * Max values
 * ~1500 1500 1500 1500 1500 1500 ~100000 ~1000
 */

using UnityEngine;

[System.Serializable]
public struct GrowthBit
{
	public float x1;
	public float y1;
	public float z1;
	public float x2;
	public float y2;
	public float z2;
	public float id;
	public float age;
}
