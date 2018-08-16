using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TestCameralCtrl : MonoBehaviour {
    public MathUtils.EaseType easeType = MathUtils.EaseType.easeInExpo;
    public GameObject Cam;
    public float speed;

    public Vector2 pos_min;
    public Vector2 pos_max;

    public bool rotate;
    public Vector3 angleX_min;
    public Vector3 angleX_max;
    public Vector3 angleZ_min;
    public Vector3 angleZ_max;

    bool dragging = false;
    Vector3 startDragPos;
    Vector3 currDragPos;
    Vector3 targetMovingPos;
    Vector3 startMovingPos;
    Vector3 currMovingPos;
    float startMovingTime;

    Vector2 movingRatio;
    Quaternion cameraRotDistant;

    void replace(Vector3 s, ref Vector3 d) {
        if (s.x != 0) {
            d.x = s.x;
        } else if (s.y != 0) {
            d.y = s.y;
        } else if (s.z != 0) {
            d.z = s.z;
        }
    }
    
    void Start () {
        movingRatio.x = 100f / ((float)Screen.width);
        movingRatio.y = 100f / ((float)Screen.height);

        Vector3 pos = Cam.transform.localPosition;
        startMovingPos = pos;
        currMovingPos = pos;
        targetMovingPos = pos;
        cameraRotDistant = Cam.transform.rotation;
	}
		
	void Update () {
        currMovingPos.y = 0;
        updateCamera();

        Vector3 finalPos = currMovingPos;
        finalPos.x = Mathf.Clamp(finalPos.x, pos_min.x, pos_max.x);
        finalPos.z = Mathf.Clamp(finalPos.z, pos_min.y, pos_max.y);
        currMovingPos = finalPos;
        Cam.transform.localPosition = currMovingPos;

        if (rotate) {
            float ratioX = (finalPos.x - pos_min.x) / (pos_max.x - pos_min.x);
            float ratioZ = (finalPos.z - pos_min.y) / (pos_max.y - pos_min.y);
            Vector3 angleX = Vector3.Lerp(angleX_min, angleX_max, ratioX);
            Vector3 angleZ = Vector3.Lerp(angleZ_min, angleZ_max, ratioZ);
            Vector3 angle = Cam.transform.localEulerAngles;
            replace(angleX, ref angle);
            replace(angleZ, ref angle);
            Cam.transform.localEulerAngles = angle;
        }
	}

    void updateCamera() {
        if (Input.GetMouseButtonDown(0)) {
            dragging = true;
            startDragPos = Input.mousePosition;

            targetMovingPos = currMovingPos;
            startMovingPos = targetMovingPos;

            cameraRotDistant = Quaternion.Euler(Cam.transform.rotation.eulerAngles);
            startMovingTime = Time.time;
        } else if (Input.GetMouseButton(0) && dragging) {
            dragging = true;
            currDragPos = Input.mousePosition;
        } else {
            dragging = false;
        }

        Vector3 delta;
        if (dragging) {
            delta = currDragPos - startDragPos;
            float movingX = delta.x * movingRatio.x * speed;
            float movingY = delta.y * movingRatio.y * speed;
            //targetMovingPos = startMovingPos + cameraRotDistant * new Vector3(-movingX, 0, -movingY);
            targetMovingPos = startMovingPos + new Vector3(-movingX, 0, -movingY);
        }

        Vector3 pos = currMovingPos;
        delta = targetMovingPos - pos;
        pos.x = MathUtils.ease(pos.x, targetMovingPos.x + delta.x * 1.2f, Time.deltaTime, easeType);
        pos.z = MathUtils.ease(pos.z, targetMovingPos.z + delta.z * 1.2f, Time.deltaTime, easeType);
        currMovingPos = pos;
    }
}
