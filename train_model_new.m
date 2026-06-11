% =========================================================================
% FILE    : train_model.m
% TUJUAN  : Melatih model SVM (RBF, multi-class ECOC) untuk klasifikasi
%           15 kelas sayuran menggunakan fitur warna (Color Moments)
%           dan tekstur (GLCM) yang diekstrak secara manual.
%
% STRUKTUR DATASET:
%   dataset/train/  -> 1.200 gambar x 15 kelas = 18.000 gambar total
%   dataset/test/   -> Tidak digunakan dalam script ini
%
% SPLIT DATA (dilakukan otomatis oleh program):
%   80% -> Data Training  (14.400 gambar)
%   20% -> Data Validasi  (3.600 gambar)
%
% CARA PAKAI:
%   1. Pastikan folder 'dataset/train/' berada satu level dengan file ini.
%   2. Jalankan script ini di MATLAB.
%   3. Setelah selesai, file 'model_svm_sayur.mat' akan terbuat otomatis.
% =========================================================================

clc; clear; close all;

%% -------------------------------------------------------------------------
%  BAGIAN 1 : LOAD DATASET
%  Menggunakan imageDatastore untuk membaca semua gambar dari folder train.
%  Seluruh 18.000 gambar (1.200 per kelas x 15 kelas) dimuat sepenuhnya.
%  Split 80/20 dilakukan otomatis oleh program di Bagian 3.
% -------------------------------------------------------------------------

datasetPath = fullfile('dataset', 'train');   % Path relatif ke folder train

fprintf('>> Memuat dataset dari: %s\n', datasetPath);

% Buat imageDatastore — MATLAB otomatis mendeteksi subfolder sebagai label
imds = imageDatastore(datasetPath, ...
    'IncludeSubfolders', true, ...
    'LabelSource',       'foldernames');

% Tampilkan ringkasan kelas yang terdeteksi
classNames = categories(imds.Labels);
numClasses  = numel(classNames);
fprintf('>> Kelas terdeteksi (%d): %s\n', numClasses, strjoin(classNames, ', '));
fprintf('>> Total gambar yang dimuat: %d\n', numel(imds.Labels));

%% -------------------------------------------------------------------------
%  BAGIAN 2 : EKSTRAKSI FITUR UNTUK SELURUH DATASET
%  Setiap gambar diproses melalui pipeline:
%    preprocessing → segmentasi HSV → morfologi → color moments + GLCM
% -------------------------------------------------------------------------

numImages  = numel(imds.Labels);
numFeatures = 10;  % 6 color moments (mean+std R,G,B) + 4 GLCM (Con,Cor,Eng,Hom)

featureMatrix = zeros(numImages, numFeatures);  % Pre-alokasi matriks fitur
labelVector   = imds.Labels;                    % Vektor label ground-truth

fprintf('\n>> Memulai ekstraksi fitur (%d gambar)...\n', numImages);

for i = 1:numImages
    % Baca satu gambar dari datastore
    img = readimage(imds, i);

    % Panggil fungsi ekstraksi fitur (didefinisikan di bawah)
    featureMatrix(i, :) = extractFeatures(img);

    % Tampilkan progres setiap 100 gambar
    if mod(i, 100) == 0
        fprintf('   Proses gambar %d / %d\n', i, numImages);
    end
end

fprintf('>> Ekstraksi fitur selesai.\n');

%% -------------------------------------------------------------------------
%  BAGIAN 3 : SPLIT DATA OTOMATIS — 80% TRAINING / 20% VALIDASI
%  cvpartition membagi data secara stratified (merata antar kelas),
%  sehingga proporsi setiap kelas terjaga di kedua set.
%
%  Dari total 18.000 gambar:
%    80% -> 14.400 gambar untuk training
%    20% ->  3.600 gambar untuk validasi
%
%  Catatan: folder dataset/test/ tidak digunakan dalam script ini.
%           Split dilakukan sepenuhnya dari dataset/train/.
% -------------------------------------------------------------------------

cv = cvpartition(labelVector, 'HoldOut', 0.2);  % 20% untuk validasi

% Indeks boolean untuk split
trainIdx = training(cv);
valIdx   = test(cv);

X_train = featureMatrix(trainIdx, :);
Y_train = labelVector(trainIdx);
X_val   = featureMatrix(valIdx,   :);
Y_val   = labelVector(valIdx);

fprintf('>> Data training : %d gambar (80%%)\n', sum(trainIdx));
fprintf('>> Data validasi : %d gambar (20%%)\n', sum(valIdx));

%% -------------------------------------------------------------------------
%  BAGIAN 4 : PELATIHAN MODEL SVM MULTI-CLASS (ECOC)
%  - templateSVM   : mendefinisikan SVM individual dengan kernel RBF.
%  - fitcecoc      : membungkus SVM menjadi classifier multi-class
%                    menggunakan strategi Error-Correcting Output Codes
%                    (one-vs-one secara default).
%  - KernelScale   : 'auto' agar MATLAB otomatis menentukan gamma RBF.
%  - BoxConstraint : Nilai C regularisasi (default 1 — bisa di-tune).
% -------------------------------------------------------------------------

fprintf('\n>> Melatih model SVM RBF (ECOC) ...\n');

svmTemplate = templateSVM( ...
    'KernelFunction', 'rbf',  ...   % Radial Basis Function kernel
    'KernelScale',    'auto', ...   % Gamma dihitung otomatis (1/sqrt(2*median))
    'BoxConstraint',  1,      ...   % Nilai C — penalty untuk misclassification
    'Standardize',    true);        % Standarisasi fitur agar skala seragam

% Latih classifier ECOC (multi-class)
model_svm = fitcecoc(X_train, Y_train, ...
    'Learners',  svmTemplate, ...
    'ClassNames', classNames);

fprintf('>> Pelatihan selesai.\n');

%% -------------------------------------------------------------------------
%  BAGIAN 5 : EVALUASI MODEL DENGAN DATA VALIDASI
%  Confusion matrix menampilkan seberapa baik model membedakan setiap kelas.
%  Akurasi dihitung dari proporsi prediksi yang benar pada data validasi
%  (3.600 gambar — 20% dari total dataset training).
% -------------------------------------------------------------------------

fprintf('\n>> Mengevaluasi model pada data validasi...\n');

Y_pred   = predict(model_svm, X_val);
accuracy = sum(Y_pred == Y_val) / numel(Y_val) * 100;

fprintf('>> Akurasi pada data validasi: %.2f%%\n', accuracy);

% Tampilkan Confusion Matrix secara visual
figure('Name', 'Confusion Matrix — SVM Sayuran', 'NumberTitle', 'off');

% Paksa kedua variabel menjadi tipe data categorical
Y_val_cat  = categorical(Y_val);
Y_pred_cat = categorical(Y_pred);

% Jalankan confusionchart menggunakan variabel yang sudah seragam
confusionchart(Y_val_cat, Y_pred_cat, ...
    'Title',              sprintf('Confusion Matrix — Validasi (Akurasi: %.2f%%)', accuracy), ...
    'RowSummary',         'row-normalized', ...
    'ColumnSummary',      'column-normalized');

%% -------------------------------------------------------------------------
%  BAGIAN 6 : SIMPAN MODEL
%  Model disimpan beserta daftar nama kelas agar app_gui.m bisa memuatnya
%  dan menampilkan label prediksi yang benar.
% -------------------------------------------------------------------------

save('model_svm_sayur.mat', 'model_svm', 'classNames');
fprintf('\n>> Model berhasil disimpan ke "model_svm_sayur.mat".\n');
fprintf('>> Jalankan app_gui.m untuk menggunakan model.\n');


%% =========================================================================
%  FUNGSI LOKAL : extractFeatures
%  Menerima satu gambar RGB, mengembalikan vektor fitur 1x10.
%  Pipeline: Konversi HSV → Threshold → Morfologi → Color Moments + GLCM
% =========================================================================

function features = extractFeatures(img)

    % --- Pastikan gambar berukuran 224x224 dan bertipe uint8 ---
    if size(img, 1) ~= 224 || size(img, 2) ~= 224
        img = imresize(img, [224 224]);
    end
    if ~isa(img, 'uint8')
        img = im2uint8(img);
    end

    % -----------------------------------------------------------------------
    %  LANGKAH A : KONVERSI RGB → HSV
    %  HSV lebih robust terhadap variasi pencahayaan dibanding RGB.
    %  Kanal H (Hue) merepresentasikan warna murni (0–1 → 0°–360°).
    %  Kanal S (Saturation) merepresentasikan kemurnian warna (0=abu, 1=jenuh).
    %  Kanal V (Value) merepresentasikan kecerahan.
    % -----------------------------------------------------------------------
    imgHSV = rgb2hsv(img);          % Output: double, rentang [0, 1]
    H = imgHSV(:,:,1);
    S = imgHSV(:,:,2);
    V = imgHSV(:,:,3);

    % -----------------------------------------------------------------------
    %  LANGKAH B : COLOR MASKING (THRESHOLDING HSV)
    %  Strategi: Buang piksel yang kemungkinan besar adalah background putih,
    %  abu-abu, atau hitam. Sayuran umumnya memiliki S tinggi dan V sedang.
    %
    %  Threshold yang digunakan (berdasarkan best practice sayuran berwarna):
    %    S > 0.15  : Buang piksel abu-abu / putih (saturation rendah)
    %    V > 0.10  : Buang piksel sangat gelap / hitam
    %    V < 0.95  : Buang piksel sangat terang / putih overexposed
    %
    %  Masker berbasis Hue tidak digunakan secara ketat karena 15 kelas
    %  sayuran mencakup spektrum warna yang sangat luas (merah, hijau,
    %  orange, ungu, putih). Masker S+V sudah cukup memisahkan background.
    % -----------------------------------------------------------------------
    mask = (S > 0.15) & (V > 0.10) & (V < 0.95);

    % -----------------------------------------------------------------------
    %  LANGKAH C : MORPHOLOGICAL OPERATIONS
    %  Tujuan: membersihkan noise kecil dan menutup lubang di dalam objek.
    %
    %  imopen  (erosi lalu dilasi) : menghapus noise kecil di luar objek.
    %  imclose (dilasi lalu erosi) : menutup lubang kecil di dalam objek.
    %  bwareaopen              : menghapus komponen kecil (< 500 piksel).
    %
    %  Structuring element 'disk' radius 3 dipilih karena bentuk membulat
    %  cocok untuk objek organik seperti sayuran.
    % -----------------------------------------------------------------------
    se = strel('disk', 3);              % Structuring element disk radius 3
    mask = imopen(mask, se);            % Hapus noise kecil di luar objek
    mask = imclose(mask, se);           % Tutup lubang di dalam objek
    mask = bwareaopen(mask, 500);       % Hapus komponen < 500 piksel

    % Fallback: jika mask kosong (gambar tidak biasa), gunakan semua piksel
    if sum(mask(:)) == 0
        mask = true(size(mask));
    end

    % -----------------------------------------------------------------------
    %  LANGKAH D : TERAPKAN MASK KE GAMBAR RGB
    %  Hanya piksel objek (mask=1) yang digunakan untuk perhitungan fitur.
    %  Piksel background tidak ikut dalam statistik.
    % -----------------------------------------------------------------------
    R = double(img(:,:,1));
    G = double(img(:,:,2));
    B = double(img(:,:,3));

    R_obj = R(mask);    % Hanya piksel objek pada kanal R
    G_obj = G(mask);    % Hanya piksel objek pada kanal G
    B_obj = B(mask);    % Hanya piksel objek pada kanal B

    % -----------------------------------------------------------------------
    %  LANGKAH E : EKSTRAKSI CIRI WARNA — COLOR MOMENTS
    %  Momen warna (Mean & Std Dev) per kanal R, G, B pada area objek.
    %  Mean  = nilai rata-rata intensitas warna → representasi warna dominan.
    %  Std   = sebaran nilai intensitas → representasi variasi warna objek.
    %  Total : 6 fitur (mean_R, std_R, mean_G, std_G, mean_B, std_B)
    % -----------------------------------------------------------------------
    mean_R = mean(R_obj);   std_R = std(R_obj);
    mean_G = mean(G_obj);   std_G = std(G_obj);
    mean_B = mean(B_obj);   std_B = std(B_obj);

    colorFeatures = [mean_R, std_R, mean_G, std_G, mean_B, std_B];

    % -----------------------------------------------------------------------
    %  LANGKAH F : EKSTRAKSI CIRI TEKSTUR — GLCM
    %  Gray-Level Co-occurrence Matrix (GLCM) mendeskripsikan pola tekstur
    %  permukaan objek (halus, kasar, berbintik, dsb.).
    %
    %  Proses:
    %    1. Konversi gambar RGB ke grayscale.
    %    2. Terapkan mask agar hanya area objek yang dianalisis.
    %    3. Hitung GLCM dengan offset [0 1] (pasangan piksel horizontal).
    %    4. Ekstrak properti: Contrast, Correlation, Energy, Homogeneity.
    %
    %  NumLevels=32 : kuantisasi ke 32 level abu untuk GLCM lebih stabil
    %                  dan komputasi lebih cepat dibanding 256 level default.
    %
    %  Definisi properti GLCM (graycoprops):
    %    Contrast    : mengukur perbedaan intensitas antar pasangan piksel.
    %                  Tinggi → tekstur kasar; Rendah → tekstur halus.
    %    Correlation : mengukur keteraturan pola piksel.
    %                  Tinggi → pola berulang; Rendah → pola acak.
    %    Energy      : mengukur keseragaman distribusi intensitas.
    %                  Tinggi → tekstur seragam/polos.
    %    Homogeneity : mengukur kedekatan distribusi GLCM dengan diagonal.
    %                  Tinggi → tekstur halus dan seragam.
    % -----------------------------------------------------------------------
    grayImg = rgb2gray(img);                % Konversi ke grayscale (uint8)
    grayImg(~mask) = 0;                     % Background diset 0 (hitam)

    % Normalisasi grayscale ke 32 level untuk efisiensi
    grayImg32 = uint8(double(grayImg) / 255 * 31);

    % Hitung GLCM — offset [0 1] = pasangan piksel ke kanan (arah 0°)
    glcm = graycomatrix(grayImg32, ...
        'NumLevels', 32, ...
        'Offset',    [0 1], ...
        'Symmetric', true);

    % Ekstrak 4 properti tekstur dari GLCM
    stats = graycoprops(glcm, {'Contrast','Correlation','Energy','Homogeneity'});

    glcmFeatures = [stats.Contrast, stats.Correlation, ...
                    stats.Energy,   stats.Homogeneity];

    % -----------------------------------------------------------------------
    %  GABUNGKAN SEMUA FITUR → vektor 1x10
    %  [mean_R, std_R, mean_G, std_G, mean_B, std_B,
    %   Contrast, Correlation, Energy, Homogeneity]
    % -----------------------------------------------------------------------
    features = [colorFeatures, glcmFeatures];

end
