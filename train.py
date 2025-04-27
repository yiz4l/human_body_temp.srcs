import cv2
import numpy as np
from keras.api.models import Sequential, Model
from keras.api.layers import *
from keras.api.preprocessing.image import ImageDataGenerator
import mediapipe as mp

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

model.fit(train_generator, epochs=15)

# 摄像头检测
cap = cv2.VideoCapture(0)
last_result = False
consecutive_count = 0

while True:
    ret, frame = cap.read()
    if not ret:
        break

    frame_no_bg = remove_background(frame)
    resized = cv2.resize(frame_no_bg, (64,64))
    normalized = resized / 255.0
    input_img = np.expand_dims(normalized, axis=0)

    prediction = model.predict(input_img)[0][0]
    current_result = prediction > 0.5

    if current_result and last_result:
        consecutive_count += 1
        if consecutive_count >= 2:
            cv2.putText(frame, "POSTURE ALERT!", (50,50),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0,0,255), 2)
    else:
        consecutive_count = 0

    last_result = current_result
    cv2.imshow('Posture Monitor', frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()