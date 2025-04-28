import cv2
import numpy as np
import os
import tensorflow as tf
from keras.models import load_model
import time

os.environ["CUDA_VISIBLE_DEVICES"] = "-1"

def initialize_camera():
    # 尝试更直接的方式打开摄像头
    print("尝试检测摄像头...")
    
    # 首先尝试直接打开外部摄像头 (通常索引为1或更高)
    for index in [1, 0, 2, 3]:  # 首先尝试索引1，然后是0，再尝试2和3
        print(f"尝试打开摄像头索引 {index}")
        cap = cv2.VideoCapture(index)
        if cap.isOpened():
            ret, test_frame = cap.read()
            if ret:
                print(f"成功打开摄像头 {index}")
                # 设置摄像头分辨率
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                return cap
            else:
                print(f"摄像头 {index} 无法读取帧")
                cap.release()
        else:
            print(f"无法打开摄像头 {index}")
    
    print("未找到可用的摄像头")
    return None

def process_frame(frame, model):
    # 预处理图像
    img = cv2.resize(frame, (128, 128))
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
            print("无法初始化摄像头，请检查设备连接")
            return
        
        print("开始摄像头捕获")
        
        frame_count = 0
        last_prediction_time = time.time()
        prediction_interval = 2  # 每2秒进行一次预测
        
        result = "等待分析..."
        confidence = 0.0
        
        while True:
            # 读取摄像头画面
            ret, frame = cap.read()
            if not ret:
                print("无法读取摄像头画面！")
                time.sleep(0.5)
                continue
            
            # 显示读取成功的帧
            current_time = time.time()
            
            # 只有当经过了预测间隔时间，才进行预测
            if current_time - last_prediction_time >= prediction_interval:
                # 处理图像并显示结果
                result, confidence = process_frame(frame, model)
                last_prediction_time = current_time
                frame_count += 1
                print(f"已处理 {frame_count} 帧图像，结果：{result}，置信度：{confidence:.2%}")
            
            # 在图像上显示结果
            cv2.putText(frame, f"{result} ({confidence:.2%})", 
                        (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
            cv2.imshow("Prediction Result", frame)
            
            # 使用 cv2.waitKey 保持窗口响应性
            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):  # 按 'q' 键退出
                print("用户请求退出")
                break
                
    except Exception as e:
        print(f"发生错误: {str(e)}")
        import traceback
        traceback.print_exc()
    finally:
        if 'cap' in locals() and cap is not None:
            cap.release()
        cv2.destroyAllWindows()

if __name__ == "__main__":
    main()