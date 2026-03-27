import json, numpy as np, random
from pathlib import Path
from PIL import Image
import tensorflow as tf

MODEL_PATH = Path("assets/models/mobilenet_v3_small.tflite")
POSTERS_DIR = Path("assets/posters")
OUTPUT_JSON = POSTERS_DIR / "posters_embeddings.json"
INPUT_SIZE = 224

def load_interpreter():
    interp = tf.lite.Interpreter(model_path=str(MODEL_PATH))
    interp.allocate_tensors()
    return interp

def embed(interp, img):
    img = img.convert("RGB").resize((INPUT_SIZE, INPUT_SIZE))
    arr = np.array(img, dtype=np.float32) / 255.0
    x = np.expand_dims(arr, 0)
    inp = interp.get_input_details()[0]; out = interp.get_output_details()[0]
    interp.set_tensor(inp['index'], x); interp.invoke()
    vec = interp.get_tensor(out['index'])[0].astype(float)
    vec /= max(np.linalg.norm(vec), 1e-8)  # L2
    return vec.tolist()

def perspective(img, jitter=0.12):
    w,h = img.size
    src = np.float32([[0,0],[w,0],[w,h],[0,h]])
    def j(pt):
        return [pt[0]+random.uniform(-jitter,jitter)*w,
                pt[1]+random.uniform(-jitter,jitter)*h]
    dst = np.float32([j(p) for p in src])
    # folosim Pillow -> fallback cu quadrilateral transform
    return img.transform((w,h), Image.PERSPECTIVE,
                         data=find_coeffs(dst, src),
                         resample=Image.BICUBIC)

def find_coeffs(pa, pb):
    import numpy as np
    matrix = []
    for p1, p2 in zip(pa, pb):
        matrix.append([p1[0], p1[1], 1, 0, 0, 0, -p2[0]*p1[0], -p2[0]*p1[1]])
        matrix.append([0, 0, 0, p1[0], p1[1], 1, -p2[1]*p1[0], -p2[1]*p1[1]])
    A = np.matrix(matrix, dtype=float)
    B = np.array(pb).reshape(8)
    res = np.dot(np.linalg.pinv(A), B)
    return np.array(res).reshape(8)

def augment(img):
    w,h = img.size
    crops = []
    # full
    crops.append(img)
    # center square
    m=min(w,h); x0=(w-m)//2; y0=(h-m)//2
    center = img.crop((x0,y0,x0+m,y0+m))
    crops.append(center)
    # scale crops (0.6,0.8 din latura min)
    for frac in (0.6,0.8):
        c = int(m*frac)
        x=(w-c)//2; y=(h-c)//2
        crops.append(img.crop((x,y,x+c,y+c)))
    # perspective warps pe center
    for _ in range(4):
        crops.append(perspective(center))
    # rotații moderate
    for angle in (15,-15,25,-25):
        crops.append(center.rotate(angle, expand=True, fillcolor=(0,0,0)))
    return crops

def main():
    interp = load_interpreter()
    all_emb = {}
    for img_file in sorted(POSTERS_DIR.glob("*.png")):
        name = img_file.stem
        base = Image.open(img_file)
        vecs = [embed(interp, v) for v in augment(base)]
        all_emb[name] = vecs
        print(name, len(vecs), len(vecs[0]))
    OUTPUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_JSON, "w") as f: json.dump(all_emb, f)
    print("saved", OUTPUT_JSON)

if __name__ == "__main__":
    main()