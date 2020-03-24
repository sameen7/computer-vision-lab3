alldir = 'training_images';
files =  dir(alldir);

for i = 1 : size(files, 1)
    [a, b, ext] = fileparts(files(i).name);
    if strcmp(ext, '.jpg')
        I = imread(fullfile(alldir, files(i).name));
        [numA, numB] = count_lego(I);
    end
end
% I = imread('training_images/train05.jpg');
% 
% [numA, numB] = count_lego(I);


