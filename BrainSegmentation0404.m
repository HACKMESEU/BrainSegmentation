clc;
clear;
%InputDicomFolder = 'C:\Users\dell\Desktop\S3010';   
InputDicomFolder = uigetdir({}, '选择输入文件夹');% The dicom files input folder path. 
if InputDicomFolder == 0
    msgbox('The input floser is empty!');
end
OutputDicomFolder = uigetdir({}, '选择输出文件夹');% The dicom files output folder path. 
if OutputDicomFolder == 0
    msgbox('The output floser is empty!');
end
%OutputDicomFolder = 'C:\Users\dell\Desktop\S30102'; % The dicom files output folder path.

filelist = dir(InputDicomFolder);                   % The number of dicom files. 
i=1;
tic
while i<=length(filelist)
    if filelist(i).isdir==1
         filelist = filelist([1:i-1 i+1:end]);   % skip folders
    else
         i=i+1;
    end
end

%for i = 1:length(filelist) 
i = 112;
    file = [InputDicomFolder '/' filelist(i).name];
    D = dicomread(file);                % Read one dicom file
    metadata = dicominfo(file);         %The dicom info
    d1 = D;                             
    im = squeeze(D(:,:));               %
    max_level = double(max(D(:)));
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Step1: Find the vein (high signal) and skull outside the WM & GM.

    % Using Medfilter to make image more smooth.
    D = medfilt2(D,[4,4]);     
    
    %apply some thresholding rules to ignore certain parts of data
    %D(D<=450) = 0;             %If need to ignore low levels (CSF & air)
    %D(D>=900&D<=1150) = 0;
    %D(D>=1400) = 0;            %ignore high levels (skull & other hard tissues)
    D(D<=1200) = 0;             %Ignore the low levels (WM & GM & CSF & air)
    
    %erode away thick layer (dissolve thin surrounding tissues)
    blk = ones([7 7]);

    %isolate brain mass (bwlabeln)
    %doc bwlabel
    lev = graythresh(double(im)/max_level) * max_level;    %Threshhold using Qtsu's method.
    bw = (D>=lev);
    L = bwlabeln(bw);                                      %Label connected components.

    %connected region properties
    %doc regionprops
    stats = regionprops(L,'Area');
    A = [stats.Area];
    
    %Find the biggest connected area: the vein intersted. 
    biggest = find(A==max(A));                             
    
    %remove the left areas.
    D(L~=biggest) = 0;
    
    figure;imshow(D,[]);
    % Using imdilate and rode to connet the high levels veins.
    D = imdilate(D,blk);
    D = imerode(D,blk);
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Step2: Find the WM & GM & CSF (inside the vein.)
    D2 = d1;
    D2(D2<=990) = 0;       %ignore low levels (CSF & air)
    D2(D2>=1300) = 0;      %ignore high levels (skull & other hard tissues)
    %erode away thick layer (dissolve thin surrounding tissues)
    blk = ones([7 7]);
    D2 = imerode(D2,blk);
    
    figure;imshow(D2,[]);
    %isolate brain mass (bwlabeln)
    %doc bwlabel
    lev = graythresh(double(im)/max_level) * max_level;
    bw = (D2>=lev);
    L = bwlabeln(bw); 
    
    
    %connected region properties
    %doc regionprops
    stats = regionprops(L,'Area');
    A = [stats.Area];
    biggest = find(A==max(A));
    
    %remove smaller scraps
    D2(L~=biggest) = 0;
    
    figure;imshow(D2,[]);
    %grow back main region (brian mass) - nobkpt
    D2 = imdilate(D2,blk);
    d2 = D2;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Connect the veins and brain inside.
    D = D + D2;
    D = imfill(D,'holes');
    %D (D>=1800) = 0;
    
    %Try to remove the skull outside. 
    blk = ones(10,10);
    D = imerode(D,blk);
    D = imerode(D,blk);
    D = imerode(D,blk);
    D = imerode(D,blk);
    D = imerode(D,blk);
    
    %Use the medfilter to smooth the image.  
    %%D = medfilt2(D,[10 10]);
    figure;imshow(D,[]);
    % Connect the brain inside and veins.
    D = d2 + D;
    D = imfill(D,'holes');
    
    %Use the D mask maps the origin image.
    d1(D==0) = 0; 
    figure;imagesc(d1);
    %Rewite the dicom files.
    dicomwrite(d1,[OutputDicomFolder '/' filelist(i).name],metadata);
%end
toc
