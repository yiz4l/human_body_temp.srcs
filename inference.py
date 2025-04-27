import cv2
import numpy as np
import os
import tensorflow as tf
from keras.api.models import load_model
import time

os.environ["CUDA_VISIBLE_DEVICES"] = "-1"

def initialize_camera():
    # 列出所有可用的摄像头
    camera_list = []
    index = 0
    while True:
        cap = cv2.VideoCapture(index)
        if not cap.read()[0]:
            break
        else:
            camera_list.append(index)
        cap.release()
        index += 1
    
    if len(camera_list) < 2:
        print("未检测到外接USB摄像头")
        return None
    
    # 使用最后一个检测到的摄像头（通常是外接USB摄像头）
    cap = cv2.VideoCapture(camera_list[-1])
    if not cap.isOpened():
        print("无法打开外接USB摄像头")
        return None
    
    return cap

def process_frame(frame, model):
    # 预处理图像
    img = cv2.resize(frame, (64, 64))
    img = img / 255.0
    img = np.expand_dims(img, axis=0)
    
    # 进行预测
    prediction = model.predict(img, verbose=0)
    result = "异常" if prediction[0][0] > 0.5 else "正常"
    confidence = prediction[0][0] if prediction[0][0] > 0.5 else 1 - prediction[0][0]
    
    return result, confidence

def main():
    try:
        # 加载模型
        model = load_model('saved_model/final_model.h5')
        print("模型加载成功")
        
        # 初始化摄像头
        cap = initialize_camera()
        if cap is None:
            return
        
        print("开始摄像头捕获，按'q'键退出...")
        
        while True:
            # 每5秒捕获一帧
            ret, frame = cap.read()
            if not ret:
                print("无法读取摄像头画面！")
                break
            
            # 处理图像并显示结果
            result, confidence = process_frame(frame, model)
            
            # 在图像上显示结果
            cv2.putText(frame, f"{result} ({confidence:.2%})", 
                        (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
            cv2.imshow("Prediction Result", frame)
            
            # 等待5秒或检测到'q'键按下
            if cv2.waitKey(5000) & 0xFF == ord('q'):
                break
                
    except Exception as e:
        print(f"发生错误: {str(e)}")
    finally:
        if 'cap' in locals():
            cap.release()
        cv2.destroyAllWindows()

if __name__ == "__main__":
    main()