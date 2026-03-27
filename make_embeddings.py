import json
import numpy as np
from pathlib import Path
from PIL import Image
import tensorflow as tf  # folosește tf.lite.Interpreter

MODEL_PATH = Path("assets/models/mobilenet_v3_small.tflite")
POSTERS_DIR = Path("assets/posters")
OUTPUT_JSON = POSTERS_DIR / "posters_embeddings.json"
INPUT_SIZE = 224  # model input size

def load_interpreter():
    interpreter = tf.lite.Interpreter(model_path=str(MODEL_PATH))
    interpreter.allocate_tensors()
    return interpreter

def preprocess(img_path):
    img = Image.open(img_path).convert("RGB").resize((INPUT_SIZE, INPUT_SIZE))
    arr = np.array(img, dtype=np.float32) / 255.0
    return np.expand_dims(arr, 0)  # [1,224,224,3]

def run_embedding(interpreter, x):
    inp = interpreter.get_input_details()[0]
    out = interpreter.get_output_details()[0]
    interpreter.set_tensor(inp['index'], x)
    interpreter.invoke()
    return interpreter.get_tensor(out['index'])[0].tolist()

def main():
    interpreter = load_interpreter()
    embeddings = {}
    for img_file in sorted(POSTERS_DIR.glob("*.png")):
        name = img_file.stem  # ex: afis1
        emb = run_embedding(interpreter, preprocess(img_file))
        embeddings[name] = emb
        print(f"Done {name}, embedding length={len(emb)}")
    OUTPUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_JSON, "w") as f:
        json.dump(embeddings, f)
    print(f"Saved embeddings to {OUTPUT_JSON}")

if __name__ == "__main__":
    main()