import time
import cv2
import numpy as np
from tflite_runtime.interpreter import Interpreter

# 加载 TFLite 模型
interpreter = Interpreter(model_path='model_quant.tflite')
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

cap = cv2.VideoCapture(0)  # USB 摄像头
consec = 0

while True:
    time.sleep(5)  # 每 5 秒截取一次
    ret, frame = cap.read()
    if not ret:
        continue

    # 预处理
    img = cv2.resize(frame, (64,64)) / 255.0
    input_data = np.expand_dims(img, axis=0).astype(np.float32)

    # 推理
    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()
    pred = interpreter.get_tensor(output_details[0]['index'])[0][0]
    abnormal = pred > 0.5

    # 连续两帧异常则报警
    if abnormal:
        consec += 1
        if consec >= 2:
            print("坐姿异常")
    else:
        consec = 0

# 释放
cap.release()
