%[pstruct, mask, imgLM, imgLoG] = pointSourceDetection(img, sigma, mode)
%
% Inputs :      img : input image
%             sigma : standard deviation of the Gaussian PSF
%            {mode} : parameters to estimate, default 'xyAc'
%           {alpha} : 
%
% Outputs:  pstruct : output structure with Gaussian parameters, standard deviations, p-values
%              mask : mask of significant (in amplitude) pixels
%             imgLM : image of local maxima
%            imgLoG : Laplacian of Gaussian filtered image

% Francois Aguet, April 2-6 2011

function [pstruct, mask, imgLM, imgLoG] = pointSourceDetection(img, sigma, varargin)

if mod(length(varargin),2)~=0
    error('Optional arguments need to be entered as pairs.');
end

idx = find(strcmpi(varargin, 'Mode'));
if ~isempty(idx)
    mode = varargin{idx+1};
else
    mode = 'xyAc';
end

idx = find(strcmpi(varargin, 'alpha'));
if ~isempty(idx)
    alpha = varargin{idx+1};
else
    alpha = 0.05;
end

% Gaussian kernel
w = ceil(4*sigma);
x = -w:w;
g = exp(-x.^2/(2*sigma^2));
u = ones(1,length(x));

imgXT = padarrayXT(img, [w w], 'symmetric');

% convolutions
fg = conv2(g', g, imgXT, 'valid');
fu = conv2(u', u, imgXT, 'valid');
fu2 = conv2(u', u, imgXT.^2, 'valid');

% Laplacian of Gaussian
gx2 = g.*x.^2;
imgLoG = 2*fg/sigma^2 - (conv2(g, gx2, imgXT, 'valid')+conv2(gx2, g, imgXT, 'valid'))/sigma^4;
imgLoG = imgLoG / (2*pi*sigma^2);

g = g'*g;
n = numel(g);

gsum = sum(g(:));
g2sum = sum(g(:).^2);

A_est = (fg - gsum*fu/n) / (g2sum - gsum^2/n);
c_est = (fu - A_est*gsum)/n;

J = [g(:) ones(n,1)]; % g_dA g_dc
C = inv(J'*J);

f_c = fu2 - 2*c_est.*fu + n*c_est.^2; % f-c
RSS = A_est.^2*g2sum - 2*A_est.*(fg - c_est*gsum) + f_c;
sigma_e2 = RSS/(n-3);

sigma_A = sqrt(sigma_e2*C(1,1));

% standard deviation of residuals
sigma_res = sqrt((RSS - (A_est*gsum+n*c_est - fu)/n)/(n-1));

kLevel = norminv(1 - alpha/2,0,1);

SE_sigma_c = sigma_res/sqrt(2*(n-1)) * kLevel;
df2 = (n-1) * (sigma_A.^2 + SE_sigma_c.^2).^2 ./ (sigma_A.^4 + SE_sigma_c.^4);
scomb = sqrt((sigma_A.^2 + SE_sigma_c.^2)/n);
T = (A_est - sigma_res*kLevel) ./ scomb;
pval = tcdf(real(T), df2);

% mask of admissible positions for local maxima
mask = pval > 0.95;

% local maxima
imgLM = locmax2d(imgLoG, 2*ceil(sigma)+1) .* mask;
[lmy, lmx] = find(imgLM~=0);
lmIdx = sub2ind(size(img), lmy, lmx);

if ~isempty(lmIdx)
    % run localization on local maxima
    pstruct = fitGaussians2D(img, lmx, lmy, A_est(lmIdx), sigma*ones(1,length(lmIdx)), c_est(lmIdx), mode);
    
    % eliminate isignificant amplitudes
    idx = [pstruct.pval_Ar] > 0.95;
    
    % eliminate duplicate positions (resulting from localization)
    np = length(pstruct.x);
    pM = [pstruct.x' pstruct.y'];
    idxKD = KDTreeBallQuery(pM, pM, 0.25*ones(np,1));
    idxKD = idxKD(cellfun(@(x) length(x)>1, idxKD));    

    for k = 1:length(idxKD);
        RSS = pstruct.RSS(idxKD{k});
        idx(idxKD{k}(RSS ~= min(RSS))) = 0;
    end

    
    fnames = fieldnames(pstruct);
    for k = 1:length(fnames)
        pstruct.(fnames{k}) = pstruct.(fnames{k})(idx);
    end
    pstruct.isPSF = pstruct.pval_KS > 0.05;
else
    pstruct = [];
end


% T = A_est ./ sigma_A;
% pval = tcdf(T,numel(img) - 2 - 1);
% hval = pval > 0.95;
% 
% figure; imagesc(hval); colormap(gray(2)); axis image;
% figure; imagesc(mask); colormap(gray(2)); axis image;
