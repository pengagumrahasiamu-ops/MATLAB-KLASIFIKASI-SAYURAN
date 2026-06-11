![alt text](?raw=true)

Klasifikasi Sayuran Menggunakan SVM + HSV Segmentation

Sistem klasifikasi citra sayuran berbasis **Support Vector Machine (SVM)** dengan preprocessing segmentasi warna **HSV Color Thresholding** dan ekstraksi ciri menggunakan **Color Moments** serta **GLCM (Gray-Level Co-occurrence Matrix)**. Aplikasi dilengkapi dengan antarmuka GUI interaktif yang memvisualisasikan seluruh pipeline proses pengolahan citra secara real-time.

---

## Tampilan Aplikasi

### GUI — Pipeline Visualisasi
![GUI Aplikasi](screenshots/gui.png)

### Confusion Matrix — Hasil Validasi
![Confusion Matrix](screenshots/confusion_matrix.png)

---

## Hasil Evaluasi

| Metrik | Nilai |
|---|---|
| **Akurasi Validasi** | **92.06%** |
| Jumlah kelas | 15 |
| Data validasi | 3.600 gambar |
| Model | SVM RBF + ECOC |

---

## Fitur Utama

- Segmentasi objek sayuran dari background menggunakan **HSV Color Thresholding**
- Pembersihan mask menggunakan **operasi morfologi** (imopen, imclose, bwareaopen)
- Ekstraksi ciri warna dengan **Color Moments** (mean & std kanal R, G, B)
- Ekstraksi ciri tekstur dengan **GLCM** (Contrast, Correlation, Energy, Homogeneity)
- Klasifikasi multi-kelas menggunakan **SVM RBF + ECOC** (105 binary classifier)
- Visualisasi pipeline 4 tahap secara real-time di GUI

---

## Struktur Proyek

```
project/
├── dataset/
│   ├── train/                  # Data latih (1.200 gambar x 15 kelas)
│   │   ├── Bean/
│   │   ├── Bitter_Gourd/
│   │   ├── Bottle_Gourd/
│   │   ├── Brinjal/
│   │   ├── Broccoli/
│   │   ├── Cabbage/
│   │   ├── Capsicum/
│   │   ├── Carrot/
│   │   ├── Cauliflower/
│   │   ├── Cucumber/
│   │   ├── Papaya/
│   │   ├── Potato/
│   │   ├── Pumpkin/
│   │   ├── Radish/
│   │   └── Tomato/
│   └── test/                   # Data pengujian (tidak digunakan dalam training)
├── train_model.m               # Script pelatihan model SVM
├── app_gui.m                   # Aplikasi GUI klasifikasi
├── model_svm_sayur.mat         # File model hasil pelatihan (generated)
└── README.md
```

---

## Dataset

Dataset yang digunakan adalah **Vegetable Image Dataset** yang tersedia secara publik di Kaggle.

- Sumber: [https://www.kaggle.com/datasets/misrakahmed/vegetable-image-dataset](https://www.kaggle.com/datasets/misrakahmed/vegetable-image-dataset)
- Jumlah kelas: **15 kelas sayuran**
- Jumlah gambar: **18.000 gambar** pada folder `dataset/train/` (1.200 gambar per kelas)
- Ukuran gambar: **224 × 224 piksel**, format `.jpg`
- Dataset digunakan **tanpa pre-processing tambahan** — gambar langsung diproses oleh pipeline segmentasi HSV dan ekstraksi ciri saat training berlangsung

### Daftar Kelas

| No | Kelas | No | Kelas |
|---|---|---|---|
| 1 | Bean | 9 | Cauliflower |
| 2 | Bitter Gourd | 10 | Cucumber |
| 3 | Bottle Gourd | 11 | Papaya |
| 4 | Brinjal | 12 | Potato |
| 5 | Broccoli | 13 | Pumpkin |
| 6 | Cabbage | 14 | Radish |
| 7 | Capsicum | 15 | Tomato |
| 8 | Carrot | | |

---

## Pembagian Data

Pembagian data dilakukan **secara otomatis oleh program** menggunakan `cvpartition` dengan metode stratified hold-out dari folder `dataset/train/`:

| Split | Jumlah Gambar | Persentase |
|---|---|---|
| **Training** | 14.400 | **80%** |
| **Validasi** | 3.600 | **20%** |
| **Total** | 18.000 | 100% |

> Folder `dataset/test/` tidak digunakan dalam proses training maupun validasi.

---

## Pipeline Sistem

```
Input Gambar (224×224 RGB)
        │
        ▼
① Konversi RGB → HSV
        │
        ▼
② Thresholding HSV (S > 0.15 & V > 0.10 & V < 0.95)  →  maskRaw
        │
        ▼
③ Morfologi (imopen → imclose → bwareaopen 500px)  →  mask bersih
        │
        ▼
④ Terapkan mask → Gambar tersegmentasi (background hitam)
        │
        ├─────────────────────┐
        ▼                     ▼
⑤a Color Moments         ⑤b GLCM Tekstur
   mean+std R,G,B            Contrast, Correlation
   (6 fitur)                 Energy, Homogeneity
                             (4 fitur)
        │                     │
        └─────────┬───────────┘
                  ▼
        Vektor Fitur [1 × 10]
                  │
                  ▼
        predict(model_svm, vektor)
        SVM RBF + ECOC (105 classifier)
                  │
                  ▼
        Hasil Prediksi Kelas
```

---

## Persyaratan Sistem

### Software
- **MATLAB** R2020a atau lebih baru
- **Image Processing Toolbox**
- **Statistics and Machine Learning Toolbox**

### Toolbox MATLAB yang Digunakan

| Fungsi | Toolbox |
|---|---|
| `imageDatastore`, `imresize` | Image Processing Toolbox |
| `rgb2hsv`, `imopen`, `imclose`, `bwareaopen` | Image Processing Toolbox |
| `rgb2gray`, `graycomatrix`, `graycoprops` | Image Processing Toolbox |
| `fitcecoc`, `templateSVM`, `cvpartition` | Statistics and Machine Learning Toolbox |
| `uifigure`, `uiaxes`, `uibutton` | MATLAB (built-in) |

---

## Cara Menjalankan

### Langkah 1 — Persiapan Dataset

Unduh dataset dari Kaggle dan susun sesuai struktur folder berikut:
```
project/
└── dataset/
    ├── train/
    │   ├── Bean/
    │   ├── Bitter_Gourd/
    │   └── ... (15 kelas)
    └── test/
```

### Langkah 2 — Pelatihan Model

Jalankan script pelatihan di MATLAB Command Window:
```matlab
>> train_model
```

Proses ini akan:
1. Memuat semua 18.000 gambar dari `dataset/train/`
2. Melakukan ekstraksi fitur (Color Moments + GLCM) untuk setiap gambar
3. Membagi data secara otomatis: 80% training, 20% validasi
4. Melatih model SVM RBF + ECOC
5. Menampilkan Confusion Matrix dan akurasi validasi
6. Menyimpan model ke file `model_svm_sayur.mat`

> **Catatan:** Proses ekstraksi fitur untuk 18.000 gambar membutuhkan waktu yang cukup lama. Pastikan RAM mencukupi.

### Langkah 3 — Menjalankan Aplikasi GUI

Setelah model selesai dilatih, jalankan GUI:
```matlab
>> app_gui
```

### Langkah 4 — Menggunakan Aplikasi

1. Klik tombol **"Load Image"** untuk memilih gambar sayuran
2. Klik tombol **"Proses & Prediksi"** untuk menjalankan klasifikasi
3. Amati visualisasi pipeline di 4 panel:
   - **Panel 1** — Gambar asli RGB
   - **Panel 2** — Hasil thresholding HSV (mask mentah)
   - **Panel 3** — Mask setelah pembersihan morfologi
   - **Panel 4** — Hasil segmentasi akhir
4. Lihat hasil prediksi kelas di sidebar kanan
5. Klik **"Reset"** untuk memulai ulang

---

## Penjelasan File

| File | Keterangan |
|---|---|
| `train_model.m` | Script pelatihan model. Berisi pipeline ekstraksi fitur, split data 80/20, pelatihan SVM ECOC, evaluasi, dan penyimpanan model |
| `app_gui.m` | Aplikasi GUI interaktif. Memuat model yang sudah dilatih dan menjalankan pipeline klasifikasi secara real-time |
| `model_svm_sayur.mat` | File binary berisi objek model SVM (`model_svm`) dan daftar nama kelas (`classNames`). Di-generate otomatis setelah `train_model.m` selesai dijalankan |

---

## Metode yang Digunakan

### Segmentasi — HSV Color Thresholding
Memisahkan objek sayuran dari background menggunakan threshold pada channel Saturation (S) dan Value (V) di ruang warna HSV. Background netral (putih/abu/hitam) memiliki nilai S rendah atau V ekstrem, sedangkan sayuran memiliki S tinggi dan V sedang.

### Ekstraksi Ciri — Color Moments
Mendeskripsikan karakteristik warna objek menggunakan nilai rata-rata (mean) dan standar deviasi (std) pada setiap channel R, G, B. Dihitung hanya dari piksel area objek (mask = 1).

### Ekstraksi Ciri — GLCM
Mendeskripsikan karakteristik tekstur permukaan objek menggunakan Gray-Level Co-occurrence Matrix dengan 4 properti: Contrast, Correlation, Energy, dan Homogeneity.

### Klasifikasi — SVM + RBF + ECOC
Support Vector Machine dengan kernel Radial Basis Function (RBF) untuk menangani data non-linear, dibungkus dengan strategi Error-Correcting Output Codes (ECOC) untuk klasifikasi 15 kelas menggunakan pendekatan one-vs-one (105 binary classifier).
g README.md…]()
