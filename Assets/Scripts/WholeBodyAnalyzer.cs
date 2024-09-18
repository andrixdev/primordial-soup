using UnityEngine;
using System;
using System.Collections;

public class WholeBodyAnalyzer : MonoBehaviour {
	
	public JointKineghost leftHand;
	
	private int moveIndex = 0;// For all buffer arrays replacements
	
	public float bodyEnergy;
	private float[] bodyEnergies;// Buffer
	public int buffersSize = 10;
	
	public float averageLeftHandAltitude = 0;
	private int step = 0;
	public int computeEachSteps = 5;
	
	public void Start() {
		bodyEnergies = new float[10];
	}
	
	public void Update() {
		step++;
		
		if (step % computeEachSteps == 0) {
			this.UpdateValues();
		}
		
	}
	
	public void UpdateValues () {
		moveIndex++;
		moveIndex = moveIndex % buffersSize;
		
		// Energy is super sensitive
		float nrj = 0;
		
		nrj += Mathf.Pow(leftHand.velocity.magnitude, 2.0f);
		
		// Replace newly found instantaneous energy value in buffer
		bodyEnergies[moveIndex] = nrj;
		
		// Recalculate buffer average for a less erratic energy
		bodyEnergy = 0;
		for (int i = 0; i < buffersSize; i++) {
			bodyEnergy += bodyEnergies[i];
		}
		
		// Position average for left hand since start
		int nbOfValues = step / computeEachSteps;
		float diffToAverage = leftHand.pos.y - averageLeftHandAltitude;
		
		averageLeftHandAltitude += 1.0f / nbOfValues * diffToAverage;
	}
	
}
