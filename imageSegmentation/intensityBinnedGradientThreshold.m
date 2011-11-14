function threshold = intensityBinnedGradientThreshold(im,binSize,sigma,smoothPar,force2D)
%INTENSITYBINNEDGRADIENTTHRESH thresholds an image combining gradient and intensity information
% 
% threshold = intensityBinnedGradientThreshold(im)
% threshold = intensityBinnedGradientThreshold(im,binSize)
% threshold = intensityBinnedGradientThreshold(im,binSize,sigma)
% 
% This function selects a threshold for the input image using both spatial
% gradient and absolute intensity information. For each set of intensity
% value(s), the spatial gradient values are averaged, giving a relationship
% between intensity and gradient. Then, the lowest intensity value which is
% a local maximum of gradient values is selected. This therefore attempts
% to select an intensity threshold which coincides with an area of high
% intensity gradients.
% 
% 
% Input:
% 
%   im - The image to threshold. May be 2D or 3D.
% 
%   binSize - The size of bins to group intensity values for calculating
%   average gradient. Smaller values will give more accurate threshold
%   values, but larger values will speed the calculation. Optional. Default
%   is 10.
% 
%   sigma - The sigma to use when calculating the smoothed gradient of the
%   input images. If zero, no smoothing is performed. Optional. Default is
%   1.
% 
%   smoothPar - The parameter of the smoothing spline used to select local
%   maxima in the gradient vs intensity curve. Scalar between 0 and 1,
%   where smaller values give more smoothing. Optional. Default is 1e-5
%
%   force2D - If true and a 3D matrix is input, it is assumed to be a stack
%   of 2D images, and the gradient is calculated in 2D along the first 2 dimensions.
%
% Output:
% 
%   threshold - The selected threshold value. If a threshold could not be
%   selected, NaN is returned.
% 
% Hunter Elliott
% 8/2011
%

showPlots = false;%Plots for testing/debugging

if nargin < 1 || isempty(im) || ndims(im) < 2 || ndims(im) > 3
    error('The first input must be a 2D or 3D image!!');
end

if nargin < 2 || isempty(binSize)
    binSize = 10;
elseif numel(binSize) > 1 || binSize <= 0
    error('the binSize input must be a scalar > 0!')
end

if nargin < 3 || isempty(sigma)
    sigma = 1;
elseif numel(sigma) > 1 || sigma < 0
    error('The input sigma must be a scalar >= zero!')
end

if nargin < 4 || isempty(smoothPar)
    smoothPar = 1e-5;
end

if nargin < 5 || isempty(force2D)
    force2D = false;
end

im = double(im);
nPlanes = size(im,3);
intBins = min(im(:)):binSize:max(im(:))+1;
gradAtIntVal = zeros(1,numel(intBins)-1);

if nPlanes == 1 || force2D
    for j = 1:nPlanes

        %TEMP - CONVERT THIS TO GRADIENT FILTERING!!!! (rather than
        %filtering then gradient calc) - HLE
        %Smooth the image
        if sigma > 0
            currIm = filterGauss2D(im(:,:,j),sigma);
        else
            currIm = im(:,:,j);
        end
        %Get gradient of image.
        [gX,gY] = gradient(currIm);
        g = sqrt(gX .^2 + gY .^2);    

        %Get average gradient at each intensity level
        tmp = arrayfun(@(x)(mean(mean(double(g(currIm >= intBins(x) & currIm < intBins(x+1)))))),1:numel(intBins)-1);
        tmp(isnan(tmp)) = 0;
        %Add this to the cumulative average
        gradAtIntVal = gradAtIntVal + (tmp ./ nPlanes);

    end
else
    %Do 3D gradient calc
    if sigma > 0
        [dX,dY,dZ] = gradientFilterGauss3D(im,sigma);
    else
        [dX,dY,dZ] = gradient(im);
    end
    
    g = sqrt(dX .^2 + dY .^2 + dZ .^2);                            
    
    gradAtIntVal = arrayfun(@(x)(mean(double(g(im(:) >= intBins(x) & im(:) < intBins(x+1))))),1:numel(intBins)-1);            
    
end

%Smooth the grad/int data
binCenters = intBins(1:end-1) + (binSize/2);%Use center of bins for x values
ssGradInt = csaps(binCenters,gradAtIntVal,smoothPar);
smGradInt = fnval(ssGradInt,binCenters);
%Find maxima
spDer = fnder(ssGradInt,1);
spDer2 = fnder(ssGradInt,2);
extrema = fnzeros(spDer);
if ~isempty(extrema)
    
    extrema = extrema(1,:);
    
    %evaluate 2nd deriv at extrema
    secDerExt = fnval(spDer2,extrema);
    %Find the first maximum
    iFirstMax = find(secDerExt < 0,1);        
    extVals = fnval(ssGradInt,extrema);
    threshold = extrema(iFirstMax);
else
    threshold = NaN;
end

if showPlots
    fsFigure(.5);
    plot(binCenters,gradAtIntVal);
    hold on    
    plot(binCenters,smGradInt,'r','LineWidth',2)    
    if ~isempty(extrema)
        plot(extrema,extVals,'om','MarkerSize',15);    
    end    
end