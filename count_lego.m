% First, extract target blocks by colors(red and blue), using hsv color space. Then use a series of official MATLAB functions to enhance the segmentation.
% Second, identify circles on each block.
% Finally, combine the results from first two steps, target bule lego has 8 circles on it while red one has 4.
%     The situation that target block could be occluded, flipped etc, has been considered,
%     so a blue object with 3-8 circles will be identified as ObjectA,
%     a red object with 1-4 circles will be identified as ObjectB.
% References are listed before each related code block.

function [numA, numB] = count_lego(I)
    I = im2double(I);
    IG = rgb2gray(I);
    [m, n, l] = size(I);

    % segement by color
    % https://blog.csdn.net/Bapyiste/article/details/84142148
    I_hsv = rgb2hsv(I);
    new_r = ones(m, n) * 0;
    new_b = ones(m, n) * 0;
    [row_b, col_b] = ind2sub(size(I_hsv), find(I_hsv(:, :, 1) >= 0.58 & I_hsv(:, :, 1) <= 0.69 & I_hsv(:, :, 2) >= 0.3 & I_hsv(:, :, 3) >= 0.18));
    [row_r, col_r] = ind2sub(size(I_hsv), find(I_hsv(:, :, 1) >= 0.85 & I_hsv(:, :, 2) >= 0.3 & I_hsv(:, :, 3) >= 0.18));
    for i = 1 : length(row_r)
        new_r(row_r(i),col_r(i)) = 1;
    end
    for i = 1 : length(row_b)
        new_b(row_b(i),col_b(i)) = 1;
    end

    % enhance segmentation
    % blue one
    Ib = imclose(new_b, strel('disk', 8));
    Ib = imfill(Ib, 8, 'holes');
    Ib = imopen(Ib, strel('disk', 10));
    Ib = bwareaopen(Ib, 3000);
    Ib = watershedSegment(Ib);
    
    % enhance segmentation
    % red one
    Ir = imclose(new_r, strel('disk', 8));
    Ir = imfill(Ir, 8, 'holes');
    Ir = imopen(Ir, strel('disk', 10));
    Ir = imfill(Ir, 8, 'holes');
    Ir = bwareaopen(Ir, 750);
    Ir = watershedSegment(Ir);

    % detect round object
    % https://stackoverflow.com/questions/31433655/find-a-nearly-circular-band-of-bright-pixels-in-this-image
    I_circle = imfilter(IG, fspecial('log', 18, 0.5));
    I_circle = I_circle < 0;
    I_circle = imopen(I_circle, strel('disk', 2));
    I_circle = imclose(I_circle, strel('disk', 2));
    I_circle = ~bwareaopen(~I_circle, 300);

    I_circle = imerode(I_circle, strel('disk', 2));
    I_circle = imdilate(I_circle, strel('disk', 1));
    I_circle = bwareaopen(I_circle, 150);

    I_circle = removeNoise(I_circle, 2000);
    
    % https://uk.mathworks.com/help/images/examples/identifying-round-objects.html
    [B, L, N] = bwboundaries(I_circle);

    stats = regionprops(L,'Area','Centroid');
    threshold = 0.65;
    roundList = [];
    for k = 1:N

      % obtain (X,Y) boundary coordinates corresponding to label 'k'
      boundary = B{k};

      % compute a simple estimate of the object's perimeter
      delta_sq = diff(boundary).^2;    
      perimeter = sum(sqrt(sum(delta_sq,2)));

      % obtain the area calculation corresponding to label 'k'
      area = stats(k).Area;

      % compute the roundness metric
      metric = 4*pi*area/perimeter^2;

      if metric > threshold
        roundList = [roundList k];
      end

    end

    I_circle = ismember(L, roundList);

    numA = count(Ib, I_circle, 3, 8);
    numB = count(Ir, I_circle, 1, 4);
end

% https://www.cnblogs.com/saliency/archive/2014/03/11/3593308.html
function Ia = removeNoise(I, num)
    L = bwlabeln(I, 8);
    S = regionprops(L, 'Area');
    Ia = ismember(L, find([S.Area] <= num));
end

% https://github.com/armandbancila/count-lego/blob/master/count_lego.m
function num = count(ori, circle, min, max)
    [L, n] = bwlabel(ori);
    num = 0;
    for i = 1:n
        searchRegion = circle & (L == i);
        [~, circleNum] = bwlabel(searchRegion);
        if circleNum >= min && circleNum <= max && circleNum ~= (min + 2) 
            num = num + 1;
        end
    end
end

% https://uk.mathworks.com/company/newsletters/articles/the-watershed-transform-strategies-for-image-segmentation.html
function I = watershedSegment(ori)
    d = -bwdist(~ori);
    mask = imextendedmin(d, 6);
    d2 = imimposemin(d, mask);
    ld2 = watershed(d2);
    ori(ld2 == 0) = 0;
    
    I = imerode(ori, strel('disk', 5));
end