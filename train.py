import cv2
import numpy as np
import os
from keras.api.models import Sequential, Model
from keras.api.layers import *
from keras.api.preprocessing.image import ImageDataGenerator
import mediapipe as mp
from keras.api.callbacks import ModelCheckpoint, EarlyStopping
import tensorflow as tf

# 设置使用CPU
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"

# 数据增强
train_datagen = ImageDataGenerator(
    rescale=1./255,
    rotation_range=20,
    width_shift_range=0.2,
    height_shift_range=0.2,
    shear_range=0.2,
    zoom_range=0.2,
    horizontal_flip=True,
    fill_mode='nearest',
    validation_split=0.2
)

# 背景分离
mp_selfie_segmentation = mp.solutions.selfie_segmentation
selfie_segmentation = mp_selfie_segmentation.SelfieSegmentation(model_selection=1)

def remove_background(image):
    results = selfie_segmentation.process(image)
    mask = results.segmentation_mask > 0.5
    return cv2.bitwise_and(image, image, mask=mask.astype(np.uint8))

# 改进模型
def build_model():
    input_tensor = Input(shape=(64,64,3))
    x = Conv2D(32, (3,3), activation='relu')(input_tensor)
    x = MaxPooling2D(2,2)(x)
    x = Conv2D(64, (3,3), activation='relu')(x)
    x = MaxPooling2D(2,2)(x)
    x = Conv2D(128, (3,3), activation='relu')(x)
    x = MaxPooling2D(2,2)(x)
    x = Flatten()(x)
    x = Dense(256, activation='relu')(x)
    x = Dropout(0.5)(x)
    output = Dense(1, activation='sigmoid')(x)
    return Model(inputs=input_tensor, outputs=output)

model = build_model()
model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])

# 训练模型
train_generator = train_datagen.flow_from_directory(
    'dataset',
    target_size=(64,64),
    batch_size=32,
    class_mode='binary',
    subset='training'
)

val_generator = train_datagen.flow_from_directory(
    'dataset',
    target_size=(64,64),
    batch_size=32,
    class_mode='binary',
    subset='validation'
)

checkpoint = ModelCheckpoint(
    'best_model.h5', monitor='val_accuracy',
    save_best_only=True, verbose=1
)

early_stop = EarlyStopping(
    monitor='val_loss', patience=3,
    restore_best_weights=True, verbose=1
)

# 训练模型
history = model.fit(
    train_generator,
    validation_data=val_generator,
    epochs=50,
    callbacks=[checkpoint, early_stop])

# 保存最终模型
if not os.path.exists('saved_model'):
    os.makedirs('saved_model')
model.save('saved_model/final_model.h5')

print("模型训练完成并保存")