% =========================================================================
% FILE    : app_gui.m
% TUJUAN  : Aplikasi GUI interaktif untuk klasifikasi sayuran menggunakan
%           model SVM yang sudah dilatih (model_svm_sayur.mat).
% CARA PAKAI:
%   1. Pastikan 'model_svm_sayur.mat' berada di folder yang sama.
%   2. Jalankan script ini di MATLAB: >> app_gui
%   3. Klik "Load Image" → pilih gambar sayur.
%   4. Klik "Proses & Prediksi" → lihat hasil segmentasi dan prediksi.
% =========================================================================

function app_gui()

    clc;

    %% ---------------------------------------------------------------------
    %  BAGIAN 1 : MUAT MODEL SVM
    %  Model dimuat sekali saat aplikasi dibuka dan disimpan di appData
    %  (struct yang dibagikan ke semua callback via UserData figure).
    % ---------------------------------------------------------------------
    modelFile = 'model_svm_sayur.mat';

    if ~isfile(modelFile)
        errordlg( ...
            sprintf('File "%s" tidak ditemukan.\nJalankan train_model.m terlebih dahulu.', modelFile), ...
            'Model Tidak Ditemukan');
        return;
    end

    fprintf('>> Memuat model dari "%s"...\n', modelFile);
    loaded      = load(modelFile, 'model_svm', 'classNames');
    model_svm   = loaded.model_svm;
    classNames  = loaded.classNames;
    fprintf('>> Model berhasil dimuat. Kelas: %s\n', strjoin(classNames, ', '));

    %% ---------------------------------------------------------------------
    %  BAGIAN 2 : BUAT JENDELA UTAMA (uifigure)
    %  uifigure adalah figure modern MATLAB (App Designer-style) yang
    %  mendukung komponen UI terbaru seperti uilabel, uibutton, dsb.
    %  Position: [x_dari_kiri, y_dari_bawah, lebar, tinggi] dalam piksel.
    % ---------------------------------------------------------------------

    fig = uifigure( ...
        'Name',       'Klasifikasi Sayuran — SVM + HSV Segmentation', ...
        'Position',   [60, 80, 1400, 680], ...  % Diperlebar untuk 4 axes horizontal
        'Color',      [0.13, 0.13, 0.15], ...   % Background gelap
        'Resize',     'off');

    % Simpan data bersama (state aplikasi) di UserData figure
    % Ini menggantikan 'global variable' yang kurang aman
    appData.model_svm  = model_svm;
    appData.classNames = classNames;
    appData.imgLoaded  = [];          % Gambar yang sedang aktif
    fig.UserData = appData;

    %% ---------------------------------------------------------------------
    %  BAGIAN 3 : PANEL KIRI — VISUALISASI (3 Axes)
    %  Tiga axes menampilkan: gambar asli, binary mask, dan hasil segmentasi.
    %  Panel menggunakan warna gelap agar gambar lebih menonjol.
    % ---------------------------------------------------------------------

    % --- Panel kiri (container untuk 4 axes berjajar horizontal) ---
    % Lebar diperbesar untuk menampung 4 axes dalam 1 baris
    % Position: [x, y, lebar, tinggi] relatif terhadap figure
    panelLeft = uipanel(fig, ...
        'Position',         [10, 10, 1030, 660], ...
        'BackgroundColor',  [0.15, 0.15, 0.17], ...
        'BorderType',       'none');

    % Judul panel kiri
    uilabel(panelLeft, ...
        'Text',             'Visualisasi Pipeline Proses Pengolahan Citra', ...
        'Position',         [0, 628, 1030, 28], ...
        'FontSize',         14, ...
        'FontWeight',       'bold', ...
        'FontColor',        [0.85, 0.85, 0.85], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',  [0.15, 0.15, 0.17]);

    % -----------------------------------------------------------------------
    %  Layout 4 Axes horizontal (1 baris x 4 kolom):
    %
    %  Lebar panel kiri : 1030 px
    %  Padding kiri/kanan: 10 px masing-masing
    %  Jarak antar axes : 10 px (3 celah)
    %  Lebar tiap axes  : (1030 - 20 - 30) / 4 = 245 px
    %
    %  Posisi X tiap axes:
    %    Axes 1: x = 10
    %    Axes 2: x = 10 + 245 + 10 = 265
    %    Axes 3: x = 265 + 245 + 10 = 520
    %    Axes 4: x = 520 + 245 + 10 = 775
    %
    %  Tinggi axes: 580 px (mengisi hampir seluruh tinggi panel)
    %  Posisi Y: 30 px dari bawah (ruang untuk label sumbu jika perlu)
    % -----------------------------------------------------------------------

    axW = 245;   % Lebar tiap axes
    axH = 580;   % Tinggi tiap axes
    axY = 35;    % Posisi Y dari bawah panel

    % -----------------------------------------------------------------------
    %  AXES 1 : Gambar Asli RGB
    %  Menampilkan gambar RGB yang diupload pengguna tanpa modifikasi.
    % -----------------------------------------------------------------------
    axOriginal = uiaxes(panelLeft, ...
        'Position',   [10, axY, axW, axH]);
    title(axOriginal, 'Gambar Asli (RGB)', ...
        'Color', [0.9 0.9 0.9], 'FontSize', 10, 'FontWeight', 'bold');
    axOriginal.Color  = [0.08 0.08 0.10];
    axOriginal.XColor = 'none';
    axOriginal.YColor = 'none';
    axOriginal.Box    = 'off';

    % -----------------------------------------------------------------------
    %  AXES 2 (BARU) : Hasil Thresholding HSV Murni
    %  Menampilkan mask biner SEBELUM pembersihan morfologi.
    %  Biasanya masih terdapat bintik-bintik noise putih/hitam kecil
    %  karena belum melalui imopen, imclose, dan bwareaopen.
    % -----------------------------------------------------------------------
    axHSVRaw = uiaxes(panelLeft, ...
        'Position',   [265, axY, axW, axH]);
    title(axHSVRaw, 'Thresholding HSV (Raw)', ...
        'Color', [1.0 0.75 0.3], 'FontSize', 10, 'FontWeight', 'bold');
    axHSVRaw.Color  = [0.08 0.08 0.10];
    axHSVRaw.XColor = 'none';
    axHSVRaw.YColor = 'none';
    axHSVRaw.Box    = 'off';

    % -----------------------------------------------------------------------
    %  AXES 3 : Hasil Setelah Pembersihan Morfologi
    %  Menampilkan mask biner SESUDAH imopen + imclose + bwareaopen.
    %  Mask sudah bersih, solid, tanpa bintik noise.
    % -----------------------------------------------------------------------
    axMask = uiaxes(panelLeft, ...
        'Position',   [520, axY, axW, axH]);
    title(axMask, 'Mask Setelah Morfologi (Bersih)', ...
        'Color', [0.5 1.0 0.6], 'FontSize', 10, 'FontWeight', 'bold');
    axMask.Color  = [0.08 0.08 0.10];
    axMask.XColor = 'none';
    axMask.YColor = 'none';
    axMask.Box    = 'off';

    % -----------------------------------------------------------------------
    %  AXES 4 : Hasil Segmentasi Akhir
    %  Menampilkan gambar sayur asli dengan background dihitamkan (= 0).
    %  Ini adalah output akhir dari seluruh pipeline segmentasi.
    % -----------------------------------------------------------------------
    axSegmented = uiaxes(panelLeft, ...
        'Position',   [775, axY, axW, axH]);
    title(axSegmented, 'Segmentasi Akhir (Objek)', ...
        'Color', [0.5 0.8 1.0], 'FontSize', 10, 'FontWeight', 'bold');
    axSegmented.Color  = [0.08 0.08 0.10];
    axSegmented.XColor = 'none';
    axSegmented.YColor = 'none';
    axSegmented.Box    = 'off';

    %% ---------------------------------------------------------------------
    %  BAGIAN 4 : PANEL KANAN — KONTROL & OUTPUT
    %  Berisi tombol input, informasi file, dan hasil prediksi.
    % ---------------------------------------------------------------------

    panelRight = uipanel(fig, ...
        'Position',         [1048, 10, 344, 660], ...
        'BackgroundColor',  [0.15, 0.15, 0.17], ...
        'BorderType',       'none');

    % Judul panel kanan
    uilabel(panelRight, ...
        'Text',             'Kontrol & Hasil Prediksi', ...
        'Position',         [0, 628, 344, 28], ...
        'FontSize',         14, ...
        'FontWeight',       'bold', ...
        'FontColor',        [0.85, 0.85, 0.85], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',  [0.15, 0.15, 0.17]);

    % --- Separator visual ---
    uilabel(panelRight, ...
        'Text',             '─────────────────────────────', ...
        'Position',         [10, 605, 324, 20], ...
        'FontColor',        [0.35, 0.35, 0.40], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',  [0.15, 0.15, 0.17]);

    % -----------------------------------------------------------------------
    %  TOMBOL 1 : Load Image
    %  Membuka dialog pemilihan file gambar menggunakan uigetfile.
    %  Format yang didukung: jpg, jpeg, png, bmp.
    % -----------------------------------------------------------------------
    uilabel(panelRight, ...
        'Text',             'LANGKAH 1 — PILIH GAMBAR', ...
        'Position',         [10, 575, 324, 22], ...
        'FontSize',         10, ...
        'FontColor',        [0.55, 0.75, 0.95], ...
        'FontWeight',       'bold', ...
        'BackgroundColor',  [0.15, 0.15, 0.17]);

    btnLoad = uibutton(panelRight, ...
        'Text',             '📁  Load Image', ...
        'Position',         [20, 535, 304, 40], ...
        'FontSize',         13, ...
        'FontWeight',       'bold', ...
        'BackgroundColor',  [0.22, 0.45, 0.70], ...
        'FontColor',        [1 1 1], ...
        'ButtonPushedFcn',  @(btn, ~) cbLoadImage(fig, axOriginal, axHSVRaw, axMask, axSegmented));

    % Label info nama file yang dipilih
    lblFilename = uilabel(panelRight, ...
        'Text',             'Belum ada gambar dipilih...', ...
        'Position',         [20, 505, 304, 28], ...
        'FontSize',         10, ...
        'FontColor',        [0.65, 0.65, 0.65], ...
        'WordWrap',         'on', ...
        'BackgroundColor',  [0.15, 0.15, 0.17]);

    % Simpan referensi lblFilename ke appData
    appData2 = fig.UserData;
    appData2.lblFilename = lblFilename;
    fig.UserData = appData2;

    % --- Separator ---
    uilabel(panelRight, ...
        'Text',             '─────────────────────────────', ...
        'Position',         [10, 490, 324, 20], ...
        'FontColor',        [0.35, 0.35, 0.40], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',  [0.15, 0.15, 0.17]);

    % -----------------------------------------------------------------------
    %  TOMBOL 2 : Proses & Prediksi
    %  Menjalankan pipeline lengkap: segmentasi → ekstraksi fitur → prediksi.
    % -----------------------------------------------------------------------
    uilabel(panelRight, ...
        'Text',             'LANGKAH 2 — PROSES & PREDIKSI', ...
        'Position',         [10, 460, 324, 22], ...
        'FontSize',         10, ...
        'FontColor',        [0.55, 0.75, 0.95], ...
        'FontWeight',       'bold', ...
        'BackgroundColor',  [0.15, 0.15, 0.17]);

    btnPredict = uibutton(panelRight, ...
        'Text',             '🔍  Proses & Prediksi', ...
        'Position',         [20, 420, 304, 40], ...
        'FontSize',         13, ...
        'FontWeight',       'bold', ...
        'BackgroundColor',  [0.18, 0.55, 0.34], ...
        'FontColor',        [1 1 1], ...
        'ButtonPushedFcn',  @(btn, ~) cbPredict(fig, axOriginal, axHSVRaw, axMask, axSegmented));

    % --- Separator ---
    uilabel(panelRight, ...
        'Text',             '─────────────────────────────', ...
        'Position',         [10, 400, 324, 20], ...
        'FontColor',        [0.35, 0.35, 0.40], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',  [0.15, 0.15, 0.17]);

    % -----------------------------------------------------------------------
    %  AREA OUTPUT : Hasil Prediksi
    %  Menampilkan nama kelas prediksi dengan huruf besar dan jelas.
    % -----------------------------------------------------------------------
    uilabel(panelRight, ...
        'Text',             'HASIL PREDIKSI:', ...
        'Position',         [10, 365, 324, 25], ...
        'FontSize',         12, ...
        'FontColor',        [0.85, 0.85, 0.85], ...
        'FontWeight',       'bold', ...
        'BackgroundColor',  [0.15, 0.15, 0.17]);

    % Kotak background untuk label prediksi
    uipanel(panelRight, ...
        'Position',         [15, 245, 314, 120], ...
        'BackgroundColor',  [0.10, 0.12, 0.14], ...
        'BorderType',       'line', ...
        'HighlightColor',   [0.30, 0.55, 0.80]);

    % Label nama kelas prediksi (teks besar, mencolok)
    lblPrediksi = uilabel(panelRight, ...
        'Text',             '—', ...
        'Position',         [20, 255, 304, 100], ...
        'FontSize',         32, ...
        'FontWeight',       'bold', ...
        'FontColor',        [0.35, 0.90, 0.55], ...   % Hijau terang
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment',    'center', ...
        'WordWrap',         'on', ...
        'BackgroundColor',  [0.10, 0.12, 0.14]);

    % Axes untuk bar chart Top-3 Prediksi
    axTop3 = uiaxes(panelRight, ...
        'Position',         [15, 140, 314, 115], ...
        'Color',            [0.10, 0.12, 0.14], ...
        'XColor',           [0.75, 0.75, 0.75], ...
        'YColor',           [0.75, 0.75, 0.75], ...
        'GridColor',        [0.30, 0.30, 0.30], ...
        'FontSize',         10);
    title(axTop3, 'Top-3 Prediksi', 'Color', [0.85 0.85 0.85], 'FontSize', 10);
    axTop3.XLim = [0 100];
    axTop3.Box  = 'off';
    grid(axTop3, 'on');

    % Simpan referensi output ke appData
    appData3 = fig.UserData;
    appData3.lblPrediksi = lblPrediksi;
    appData3.axTop3      = axTop3;
    fig.UserData = appData3;

    % --- Separator ---
    uilabel(panelRight, ...
        'Text',             '─────────────────────────────', ...
        'Position',         [10, 205, 324, 20], ...
        'FontColor',        [0.35, 0.35, 0.40], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',  [0.15, 0.15, 0.17]);

    % -----------------------------------------------------------------------
    %  TOMBOL RESET
    %  Mengembalikan semua komponen ke keadaan awal.
    % -----------------------------------------------------------------------
    uibutton(panelRight, ...
        'Text',             '↺  Reset', ...
        'Position',         [20, 165, 304, 32], ...
        'FontSize',         11, ...
        'BackgroundColor',  [0.35, 0.20, 0.20], ...
        'FontColor',        [1 1 1], ...
        'ButtonPushedFcn',  @(btn, ~) cbReset(fig, axOriginal, axHSVRaw, axMask, axSegmented, lblPrediksi));

    % Info versi di bagian bawah
    uilabel(panelRight, ...
        'Text',             'SVM + RBF | ECOC | HSV Segmentation | GLCM', ...
        'Position',         [10, 15, 324, 20], ...
        'FontSize',         9, ...
        'FontColor',        [0.40, 0.40, 0.45], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor',  [0.15, 0.15, 0.17]);

    fprintf('>> Aplikasi GUI berhasil dibuka.\n');

end  % END FUNCTION app_gui


%% =========================================================================
%  CALLBACK : cbLoadImage
%  Dipanggil saat tombol "Load Image" ditekan.
%  Membuka dialog file, membaca gambar, dan menampilkannya di Axes 1.
% =========================================================================

function cbLoadImage(fig, axOriginal, axHSVRaw, axMask, axSegmented)

    % Buka dialog pemilihan file gambar
    [fileName, filePath] = uigetfile( ...
        {'*.jpg;*.jpeg;*.png;*.bmp', 'File Gambar (*.jpg, *.jpeg, *.png, *.bmp)'; ...
         '*.*', 'Semua File (*.*)'}, ...
        'Pilih Gambar Sayuran');

    % Cek jika pengguna membatalkan dialog
    if isequal(fileName, 0)
        return;
    end

    fullPath = fullfile(filePath, fileName);
    img = imread(fullPath);

    % Konversi ke RGB jika grayscale atau format lain
    if size(img, 3) == 1
        img = cat(3, img, img, img);  % Grayscale → RGB
    elseif size(img, 3) == 4
        img = img(:,:,1:3);           % RGBA → RGB (buang kanal alpha)
    end

    % Resize ke 224x224 untuk konsistensi dengan training
    img = imresize(img, [224, 224]);

    % Simpan gambar ke state aplikasi
    appData = fig.UserData;
    appData.imgLoaded = img;

    % Update label nama file
    if isfield(appData, 'lblFilename')
        appData.lblFilename.Text = fileName;
    end

    fig.UserData = appData;

    % --- Tampilkan gambar asli di Axes 1 ---
    imshow(img, 'Parent', axOriginal);
    title(axOriginal, 'Gambar Asli (RGB)', ...
        'Color', [0.9 0.9 0.9], 'FontSize', 10, 'FontWeight', 'bold');
    axOriginal.XColor = 'none';
    axOriginal.YColor = 'none';

    % --- Bersihkan Axes 2, 3, 4 dan kembalikan judul ---
    cla(axHSVRaw);
    title(axHSVRaw, 'Thresholding HSV (Raw)', ...
        'Color', [1.0 0.75 0.3], 'FontSize', 10, 'FontWeight', 'bold');

    cla(axMask);
    title(axMask, 'Mask Setelah Morfologi (Bersih)', ...
        'Color', [0.5 1.0 0.6], 'FontSize', 10, 'FontWeight', 'bold');

    cla(axSegmented);
    title(axSegmented, 'Segmentasi Akhir (Objek)', ...
        'Color', [0.5 0.8 1.0], 'FontSize', 10, 'FontWeight', 'bold');

    % Reset label prediksi di sidebar kanan
    appData = fig.UserData;
    if isfield(appData, 'lblPrediksi')
        appData.lblPrediksi.Text      = '—';
        appData.lblPrediksi.FontColor = [0.35, 0.90, 0.55];
    end

    fprintf('>> Gambar dimuat: %s\n', fullPath);

end


%% =========================================================================
%  CALLBACK : cbPredict
%  Dipanggil saat tombol "Proses & Prediksi" ditekan.
%  Menjalankan pipeline segmentasi + fitur + prediksi, lalu update GUI.
% =========================================================================

function cbPredict(fig, axOriginal, axHSVRaw, axMask, axSegmented)

    appData = fig.UserData;

    % Validasi: pastikan gambar sudah dimuat
    if isempty(appData.imgLoaded)
        uialert(fig, 'Belum ada gambar yang dimuat. Klik "Load Image" terlebih dahulu.', ...
            'Peringatan', 'Icon', 'warning');
        return;
    end

    img = appData.imgLoaded;

    % -----------------------------------------------------------------------
    %  LANGKAH 1 : SEGMENTASI HSV
    %  Pipeline dipisah menjadi dua tahap yang divisualisasikan secara
    %  terpisah di Axes 2 (raw) dan Axes 3 (sesudah morfologi).
    % -----------------------------------------------------------------------

    % Konversi RGB → HSV
    imgHSV = rgb2hsv(img);
    S = imgHSV(:,:,2);   % Saturation
    V = imgHSV(:,:,3);   % Value (kecerahan)

    % -----------------------------------------------------------------------
    %  TAHAP 1a : Thresholding HSV Murni (BELUM morfologi)
    %  Hasilnya disimpan di maskRaw dan ditampilkan di Axes 2.
    %  Pada tahap ini mask biasanya masih banyak noise (bintik putih/hitam)
    %  karena belum dibersihkan dengan operasi morfologi.
    %
    %  Logika threshold:
    %    S > 0.15 : buang piksel dengan saturasi rendah (abu-abu, putih)
    %    V > 0.10 : buang piksel yang terlalu gelap (hitam)
    %    V < 0.95 : buang piksel yang terlalu terang (background putih murni)
    % -----------------------------------------------------------------------
    maskRaw = (S > 0.15) & (V > 0.10) & (V < 0.95);

    % Tampilkan hasil thresholding HSV murni di Axes 2
    % (sebelum pembersihan — noise masih terlihat)
    imshow(maskRaw, 'Parent', axHSVRaw);
    title(axHSVRaw, 'Thresholding HSV (Raw)', ...
        'Color', [1.0 0.75 0.3], 'FontSize', 10, 'FontWeight', 'bold');
    axHSVRaw.XColor = 'none';
    axHSVRaw.YColor = 'none';

    % -----------------------------------------------------------------------
    %  TAHAP 1b : Pembersihan Morfologi
    %  Tiga operasi morfologi diterapkan secara berurutan pada maskRaw:
    %
    %  1. imopen  : Menghapus noise kecil (bintik putih terisolasi).
    %               Erosi diikuti dilasi — objek kecil hilang, objek besar utuh.
    %  2. imclose : Menutup lubang kecil di dalam objek utama.
    %               Dilasi diikuti erosi — celah kecil dalam objek terisi.
    %  3. bwareaopen : Menghapus semua connected component dengan luas
    %               piksel < 500. Menghilangkan sisa noise yang lolos dari
    %               imopen/imclose.
    % -----------------------------------------------------------------------
    se   = strel('disk', 3);
    mask = imopen(maskRaw, se);
    mask = imclose(mask, se);
    mask = bwareaopen(mask, 500);

    % Fallback jika mask kosong (seluruh gambar terdeteksi sebagai background)
    if sum(mask(:)) == 0
        mask = true(size(mask));
    end

    % Tampilkan mask bersih di Axes 3
    imshow(mask, 'Parent', axMask);
    title(axMask, 'Mask Setelah Morfologi (Bersih)', ...
        'Color', [0.5 1.0 0.6], 'FontSize', 10, 'FontWeight', 'bold');
    axMask.XColor = 'none';
    axMask.YColor = 'none';

    % -----------------------------------------------------------------------
    %  LANGKAH 2 : BUAT CITRA TERSEGMENTASI (Axes 4)
    %  Terapkan mask 3 kanal ke gambar asli:
    %  Piksel background (mask=0) diset menjadi [0 0 0] (hitam).
    % -----------------------------------------------------------------------
    mask3ch      = repmat(mask, [1 1 3]);   % Expand mask ke 3 kanal (R,G,B)
    imgSegmented = img;
    imgSegmented(~mask3ch) = 0;             % Background = hitam

    % Tampilkan hasil segmentasi akhir di Axes 4
    imshow(imgSegmented, 'Parent', axSegmented);
    title(axSegmented, 'Segmentasi Akhir (Objek)', ...
        'Color', [0.5 0.8 1.0], 'FontSize', 10, 'FontWeight', 'bold');
    axSegmented.XColor = 'none';
    axSegmented.YColor = 'none';

    % -----------------------------------------------------------------------
    %  LANGKAH 3 : EKSTRAKSI FITUR & PREDIKSI
    %  Fitur diekstrak menggunakan fungsi lokal extractFeaturesGUI.
    %  Prediksi dilakukan dengan fungsi predict() pada model ECOC.
    % -----------------------------------------------------------------------

    featureVec  = extractFeaturesGUI(img, mask);
    model       = appData.model_svm;

    % predict() mengembalikan label kelas yang diprediksi
    % NegLoss digunakan sebagai proxy confidence (semakin besar = lebih yakin)
    [predLabel, negLoss] = predict(model, featureVec);

    predLabelStr = char(predLabel);

    % -----------------------------------------------------------------------
    %  KONVERSI NegLoss → Skor Posterior (Softmax approximation)
    %  NegLoss dari ECOC bukan probabilitas, tapi bisa di-softmax-kan
    %  untuk mendapat estimasi "kepercayaan" relatif antar kelas.
    %  Semakin besar NegLoss → semakin yakin model terhadap kelas tersebut.
    % -----------------------------------------------------------------------
    expNL      = exp(negLoss - max(negLoss));   % Stabilisasi numerik
    posterior  = expNL / sum(expNL) * 100;      % Normalisasi ke persentase

    % Urutkan dari skor tertinggi ke terendah
    [sortedScore, sortedIdx] = sort(posterior, 'descend');

    % Ambil Top-3
    top3Labels = appData.classNames(sortedIdx(1:3));
    top3Scores = sortedScore(1:3);

    % -----------------------------------------------------------------------
    %  LANGKAH 4 : TAMPILKAN HASIL PREDIKSI DI LABEL OUTPUT (Sidebar Kanan)
    % -----------------------------------------------------------------------
    if isfield(appData, 'lblPrediksi')
    % Label utama tetap menampilkan prediksi #1
    appData.lblPrediksi.Text      = upper(predLabelStr);
    appData.lblPrediksi.FontColor = [0.35, 0.90, 0.55];
    end

    fprintf('>> Top-3: 1.%s(%.1f%%) 2.%s(%.1f%%) 3.%s(%.1f%%)\n', ...
        top3Labels{1}, top3Scores(1), ...
        top3Labels{2}, top3Scores(2), ...
        top3Labels{3}, top3Scores(3));

end


%% =========================================================================
%  CALLBACK : cbReset
%  Mengembalikan semua tampilan ke keadaan awal (bersih).
% =========================================================================

function cbReset(fig, axOriginal, axHSVRaw, axMask, axSegmented, lblPrediksi)

    appData = fig.UserData;
    appData.imgLoaded = [];
    if isfield(appData, 'lblFilename')
        appData.lblFilename.Text = 'Belum ada gambar dipilih...';
    end
    fig.UserData = appData;

    % Bersihkan semua 4 axes dan kembalikan judul masing-masing
    cla(axOriginal);
    title(axOriginal,  'Gambar Asli (RGB)', ...
        'Color', [0.9 0.9 0.9], 'FontSize', 10, 'FontWeight', 'bold');

    cla(axHSVRaw);
    title(axHSVRaw, 'Thresholding HSV (Raw)', ...
        'Color', [1.0 0.75 0.3], 'FontSize', 10, 'FontWeight', 'bold');

    cla(axMask);
    title(axMask, 'Mask Setelah Morfologi (Bersih)', ...
        'Color', [0.5 1.0 0.6], 'FontSize', 10, 'FontWeight', 'bold');

    cla(axSegmented);
    title(axSegmented, 'Segmentasi Akhir (Objek)', ...
        'Color', [0.5 0.8 1.0], 'FontSize', 10, 'FontWeight', 'bold');

    % Reset label prediksi di sidebar kanan
    lblPrediksi.Text      = '—';
    lblPrediksi.FontColor = [0.35, 0.90, 0.55];

    fprintf('>> Aplikasi direset.\n');

end


%% =========================================================================
%  FUNGSI LOKAL : extractFeaturesGUI
%  Versi ekstraksi fitur untuk GUI — menerima gambar dan mask yang sudah
%  dihitung, mengembalikan vektor fitur 1x10.
%  Logika identik dengan extractFeatures() di train_model.m.
% =========================================================================

function features = extractFeaturesGUI(img, mask)

    % Pastikan tipe data benar
    if ~isa(img, 'uint8')
        img = im2uint8(img);
    end

    % --- Color Moments (Mean & Std Dev R, G, B pada area objek) ---
    R = double(img(:,:,1));
    G = double(img(:,:,2));
    B = double(img(:,:,3));

    R_obj = R(mask);
    G_obj = G(mask);
    B_obj = B(mask);

    mean_R = mean(R_obj);   std_R = std(R_obj);
    mean_G = mean(G_obj);   std_G = std(G_obj);
    mean_B = mean(B_obj);   std_B = std(B_obj);

    colorFeatures = [mean_R, std_R, mean_G, std_G, mean_B, std_B];

    % --- GLCM Texture Features ---
    grayImg = rgb2gray(img);
    grayImg(~mask) = 0;
    grayImg32 = uint8(double(grayImg) / 255 * 31);

    glcm  = graycomatrix(grayImg32, ...
        'NumLevels', 32, ...
        'Offset',    [0 1], ...
        'Symmetric', true);
    stats = graycoprops(glcm, {'Contrast','Correlation','Energy','Homogeneity'});

    glcmFeatures = [stats.Contrast, stats.Correlation, ...
                    stats.Energy,   stats.Homogeneity];

    features = [colorFeatures, glcmFeatures];

end
