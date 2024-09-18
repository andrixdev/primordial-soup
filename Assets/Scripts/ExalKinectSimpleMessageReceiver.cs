/* Copyright (c) 2019 ExT (V.Sigalkin) */

using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;

namespace extOSC.Examples
{
	public class ExalKinectSimpleMessageReceiver : MonoBehaviour
	{
		#region Public Vars

		public string Address = "/exalbody";
		public Transform head;
		public Transform spineShoulder;
		public Transform spineMid;
		public Transform spineBase;
		public Transform leftShoulder;
		public Transform leftElbow;
		public Transform leftHand;
		public Transform rightShoulder;
		public Transform rightElbow;
		public Transform rightHand;
		public Transform leftHip;
		public Transform leftKnee;
		public Transform leftFoot;
		public Transform rightHip;
		public Transform rightKnee;
		public Transform rightFoot;
		

		[Header("OSC Settings")]
		public OSCReceiver Receiver;

		#endregion

		#region Unity Methods

		protected virtual void Start()
		{
			Receiver.Bind(Address, ReceivedMessage);
		}

		#endregion

		#region Private Methods

		private void ReceivedMessage(OSCMessage msg)
		{
			//Debug.LogFormat("Received: {0}", message);
			System.Collections.Generic.List<OSCValue> arr;
			msg.ToArray(out arr);
			
			// All joints GameObject position update
			head.transform.position = new Vector3(arr[0].FloatValue, arr[1].FloatValue,	arr[2].FloatValue);
			spineShoulder.transform.position = new Vector3(arr[3].FloatValue, arr[4].FloatValue, arr[5].FloatValue);
			spineMid.transform.position = new Vector3(arr[6].FloatValue, arr[7].FloatValue,	arr[8].FloatValue);
			spineBase.transform.position = new Vector3(arr[9].FloatValue, arr[10].FloatValue, arr[11].FloatValue);
			leftShoulder.transform.position = new Vector3(arr[12].FloatValue, arr[13].FloatValue, arr[14].FloatValue);
			leftElbow.transform.position = new Vector3(arr[15].FloatValue, arr[16].FloatValue, arr[17].FloatValue);
			leftHand.transform.position = new Vector3(arr[18].FloatValue, arr[19].FloatValue, arr[20].FloatValue);
			rightShoulder.transform.position = new Vector3(arr[21].FloatValue, arr[22].FloatValue, arr[23].FloatValue);
			rightElbow.transform.position = new Vector3(arr[24].FloatValue, arr[25].FloatValue, arr[26].FloatValue);
			rightHand.transform.position = new Vector3(arr[27].FloatValue, arr[28].FloatValue, arr[29].FloatValue);
			leftHip.transform.position = new Vector3(arr[30].FloatValue, arr[31].FloatValue, arr[32].FloatValue);
			leftKnee.transform.position = new Vector3(arr[33].FloatValue, arr[34].FloatValue, arr[35].FloatValue);
			leftFoot.transform.position = new Vector3(arr[36].FloatValue, arr[37].FloatValue, arr[38].FloatValue);
			rightHip.transform.position = new Vector3(arr[39].FloatValue, arr[40].FloatValue, arr[41].FloatValue);
			rightKnee.transform.position = new Vector3(arr[42].FloatValue, arr[43].FloatValue, arr[44].FloatValue);
			rightFoot.transform.position = new Vector3(arr[45].FloatValue, arr[46].FloatValue, arr[47].FloatValue);
		}

		#endregion
	}
}