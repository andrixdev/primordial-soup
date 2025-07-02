/**
 * Alex Andrix © 2023-2024
 * This script animates a game object's rotation
 */

using UnityEngine;

public class FixedRotAnim : MonoBehaviour
{
    public float rotationSpeed = 0.5f;
    public Transform origin;
    //public float baseRotAngleX = 0;
    public float baseRotAngleY = 0;
    //public float baseRotAngleZ = 0;

    //private float angleX = 0;
    private float angleY = 0;
    //private float angleZ = 0;
    private float t = 0;

    void Start()
    {
        
    }

    void Update()
    {
        // Update rotation
        t += rotationSpeed * Time.deltaTime;
        //angleX = baseRotAngleX + angularAmplitude * Mathf.Sin(t);
        //angleY = baseRotAngleY + angularAmplitude * Mathf.Sin(t + Mathf.PI / 2);
        angleY = baseRotAngleY + t;

        gameObject.transform.localPosition = origin.position;
        gameObject.transform.localRotation = Quaternion.Euler(0, 0, 0);
        gameObject.transform.RotateAround(origin.position, Vector3.up, angleY);
        //gameObject.transform.RotateAround(origin.position, Vector3.right, angleX);
        //gameObject.transform.RotateAround(origin.position, Vector3.forward, angleZ);
        
    }

}
