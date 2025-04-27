import tensorflow as tf
import os

# 1. 加载已经训练好的模型
model_path = 'saved_model/final_model.h5'
assert os.path.exists(model_path), f"模型路径不存在: {model_path}"

model = tf.keras.models.load_model(model_path)
print("模型加载成功。")

# 2. 创建 TFLite Converter
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# 3. 开启默认优化（比如量化、降低大小、加速推理）
converter.optimizations = [tf.lite.Optimize.DEFAULT]

# 4. 转换模型
tflite_model = converter.convert()
print("TFLite模型转换成功。")

# 5. 保存 .tflite 文件
tflite_model_path = 'saved_model/model_quant.tflite'
with open(tflite_model_path, 'wb') as f:
    f.write(tflite_model)

print(f"TFLite模型已保存到: {tflite_model_path}")
