using UnityEngine;

public class EnrouleurGenerator : MonoBehaviour
{
	public int length = 15;
	public GameObject stickModel; // Textured cube
	public float speed = 1;
	public float radius = 1;
	public string sequence = "314159";
	private int[] sequenceArray;
	private GameObject[] sticks;
	private float angleMultiplier = 0;
	private int step = 0;
	
	void Start()
	{
		// Create stick gameobjects and instantiate them
		sticks = new GameObject[length];
		for (int i = 0; i < length; i++)
		{
			sticks[i] = Instantiate(stickModel);
			sticks[i].SetActive(true);
			sticks[i].transform.parent = transform;
		}
		
		// Create array with repeated sequence
		sequenceArray = new int[length];
		for (int c = 0; c < length; c++)
		{
			sequenceArray[c] = sequence[c % sequence.Length];
		}
		
	}
	
	void Update()
	{
		step++;
		angleMultiplier += speed / 1000000;
		
		Vector3 lastPos = Vector3.zero;
		float ang = 0;
		for (int i = 0; i < sticks.Length; i++)
		{
			float r = radius * Mathf.Exp(-i / 100.0f);
			float mult = sequenceArray[i];
			ang += angleMultiplier * mult;
			float ang2 = ang;
			
			float xOffset = r * Mathf.Cos(ang2);
			float yOffset = r * Mathf.Sin(ang2);
			Vector3 extraPos = (i % 2 == 0 ? -1 : 1) * new Vector3(xOffset, yOffset, 0);
			
			GameObject stick = sticks[i];
			Vector3 newPos = lastPos + extraPos;
			float size = (newPos - lastPos).magnitude;
			
			// Position tick
			Vector3 centerPos = lastPos + 0.5f * extraPos; 
			stick.transform.position = new Vector3(centerPos.x, centerPos.y, centerPos.z);
			
			// Scale tick
			stick.transform.localScale = new Vector3(size, size / 20, size / 20);

			// Rotate tick
			stick.transform.eulerAngles = new Vector3(0, 0, ang2 / Mathf.PI * 180f);
			
			lastPos = newPos;
		}
	}
}
