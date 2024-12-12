    function varargout = Klasifikasi_poteng(varargin)
        % Begin initialization code - DO NOT EDIT
        gui_Singleton = 1;
        gui_State = struct('gui_Name',       mfilename, ...
            'gui_Singleton',  gui_Singleton, ...
            'gui_OpeningFcn', @Klasifikasi_poteng_OpeningFcn, ...
            'gui_OutputFcn',  @Klasifikasi_poteng_OutputFcn, ...
            'gui_LayoutFcn',  [] , ...
            'gui_Callback',   []);
        if nargin && ischar(varargin{1})
            gui_State.gui_Callback = str2func(varargin{1});
        end
    
        if nargout
            [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
        else
            gui_mainfcn(gui_State, varargin{:});
        end
        % End initialization code - DO NOT EDIT
    
    
        % --- Executes just before Klasifikasi_mangga is made visible.
        function Klasifikasi_poteng_OpeningFcn(hObject, eventdata, handles, varargin)
            handles.output = hObject;
            guidata(hObject, handles);
            movegui(hObject,'center');
    
        % --- Outputs from this function are returned to the command line.
        function varargout = Klasifikasi_poteng_OutputFcn(hObject, eventdata, handles)
            varargout{1} = handles.output;
    
        % --- Executes on button press in pushbutton1.
        function pushbutton1_Callback(hObject, eventdata, handles)
            [nama_file, nama_path] = uigetfile({'*.jpg;*.png;*', 'Image Files'});
            if ~isequal(nama_file, 0)
                I = imread(fullfile(nama_path, nama_file));
                axes(handles.axes1);
                imshow(I);
                handles.I = I;
                I_gray = rgb2gray(I); % Konversi ke grayscale
                axes(handles.axes2);
                imshow(I_gray); % Tampilkan gambar grayscale
                handles.I_gray = I_gray;
                guidata(hObject, handles);
            else
                return;
            end
    
            function pushbutton2_Callback(hObject, eventdata, handles)
    % Memastikan gambar telah dimuat
    if ~isfield(handles, 'I')
        msgbox('Please load an image first!', 'Error', 'error');
        return;
    end

    I = handles.I;

    % Ekstraksi fitur LAB
    labImage = rgb2lab(I);
    LAB_L = labImage(:,:,1);
    LAB_A = labImage(:,:,2);
    LAB_B = labImage(:,:,3);

    % Segmentasi menggunakan metode yang sama
    grayImg = rgb2gray(I);
    grayscale = graythresh(grayImg);
    segmentation = imbinarize(grayImg, grayscale);
    axes(handles.axes5);
    imshow(segmentation);

    % Operasi morfologi
    SE_open = strel('disk', 30);     % Elemen struktural untuk opening dengan radius 30
    SE_dilate = strel('disk', 50);   % Elemen struktural untuk dilasi dengan radius 50 
    SE_erosion = strel('disk', 50);  % Elemen struktural untuk erosi dengan radius 50
    hasilOpening = imopen(segmentation, SE_open);
    axes(handles.axes6);
    imshow(hasilOpening);
    hasilDilasi = imdilate(hasilOpening, SE_dilate);
    axes(handles.axes7);
    imshow(hasilDilasi);
    bersih = bwareaopen(hasilDilasi, 100);
    axes(handles.axes8);
    imshow(bersih);
    hasilErosi = imerode(bersih, SE_erosion);
    maskColor = cast(hasilErosi, 'like', I); % Membuat mask 3 channel dari hasil erosi
    maskedImage = bsxfun(@times, I, maskColor); % Mengembalikan warna objek
    axes(handles.axes10);
    imshow(maskedImage);

    % Mengembalikan LAB
    LAB_L(~bersih) = 0;
    LAB_A(~bersih) = 0;
    LAB_B(~bersih) = 0;

    % Ekstraksi Fitur Warna LAB
    K_doub_comp = double(bersih);

    %--------LAB L------------------ 
    LAB_L(~K_doub_comp) = 0;
    lab_stats_l = regionprops(K_doub_comp, LAB_L, 'MeanIntensity');
    lab_lightness = lab_stats_l.MeanIntensity;

    %--------LAB A------------------ 
    LAB_A(~K_doub_comp) = 0;
    lab_stats_a = regionprops(K_doub_comp, LAB_A, 'MeanIntensity');
    lab_redgreen = lab_stats_a.MeanIntensity;

    %--------LAB B------------------ 
    LAB_B(~K_doub_comp) = 0;
    lab_stats_b = regionprops(K_doub_comp, LAB_B, 'MeanIntensity');
    lab_blueyellow = lab_stats_b.MeanIntensity;

    % Ekstraksi Fitur Tekstur dengan GLCM
    stats_bentuk = regionprops(K_doub_comp,'BoundingBox');
    if isempty(stats_bentuk)
        % Jika tidak ada objek yang terdeteksi, set nilai ke 0
        contrast = 0;
        correlation = 0;
        energy = 0;
        homogeneity = 0;
    else
        kropping = imcrop(I, stats_bentuk.BoundingBox);
        kropping_gray = rgb2gray(kropping);
        GLCM2 = graycomatrix(kropping_gray, 'GrayLimits', [0 255], 'NumLevels', 256);
        statsGLCM = graycoprops(GLCM2, {'Contrast', 'Correlation', 'Energy', 'Homogeneity'});
        contrast = statsGLCM.Contrast;
        correlation = statsGLCM.Correlation;
        energy = statsGLCM.Energy;
        homogeneity = statsGLCM.Homogeneity;
    end

    % Normalisasi Fitur
    load('training_results.mat', 'feature_min', 'feature_max', 'results', 'feature_combinations');

    % Dapatkan indeks fitur untuk kombinasi 'LAB_Tekstur'
    combination_name = 'LAB_Tekstur';
    idx_combination = find(strcmp(feature_combinations(:,1), combination_name));
    feature_indices = feature_combinations{idx_combination, 2};

    % Ekstrak feature_min dan feature_max untuk fitur yang digunakan
    feature_min_used = feature_min(feature_indices);
    feature_max_used = feature_max(feature_indices);

    % Buat vektor fitur
    features = [lab_lightness, lab_redgreen, lab_blueyellow, contrast, homogeneity, energy, correlation];

    % Normalisasi fitur
    features_normalized = (features - feature_min_used) ./ (feature_max_used - feature_min_used);
    features_normalized(isnan(features_normalized)) = 0;

    % Menampilkan fitur di edit box (opsional)
    set(handles.edit2, 'String', features_normalized(1)); % LAB Lightness
    set(handles.edit3, 'String', features_normalized(2)); % LAB A (Red-Green)
    set(handles.edit6, 'String', features_normalized(3)); % LAB B (Blue-Yellow)

    % Pastikan input berupa vektor kolom
    input = features_normalized';

    % Load model jaringan saraf untuk kombinasi 'LAB_Tekstur'
    net = results.(combination_name).network;

    % Prediksi kelas menggunakan model yang disimpan
    output = net(input);

    % Memetakan output ke label kelas 1 dan 2
    if output <= 1.5
        predicted_class = 1; % Kelas Mentah
    else
        predicted_class = 2; % Kelas Matang
    end

    % Menampilkan hasil klasifikasi
    if predicted_class == 1
        hasil = 'Mentah';  % Kelas 1 untuk 'Mentah'
    elseif predicted_class == 2
        hasil = 'Matang';  % Kelas 2 untuk 'Matang'
    else
        hasil = 'Unknown';  % Kelas tidak dikenali
    end

    % Menampilkan hasil pada edit box
    set(handles.edit1, 'String', hasil);

   
    function edit1_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
    
    function edit3_Callback(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
    function edit6_Callback(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
    % Hint: place code in OpeningFcn to populate axes1
    
    function edit2_Callback(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    
   
