% pStruct = fitGaussians2D(img, x, y, A, sigma, c, mode, varargin)
%
% Inputs:   img : input image
%             x : initial (or fixed) x-positions
%             y : initial (or fixed) y-positions
%             A : initial (or fixed) amplitudes
%             s : initial (or fixed) Gaussian PSF standard deviations
%             c : initial (or fixed) background intensities
%          mode : string selector for optimization parameters, any of 'xyAsc'
%
% Optional inputs : ('Mask', mask) pair with a mask of spot locations
%
%
% Output: pStruct: structure with fields:
%                  x : estimated x-positions
%                  y : estimated y-positions
%                  A : estimated amplitudes
%                  s : estimated standard deviations of the PSF
%                  c : estimated background intensities
%
%             x_pstd : standard deviations, estimated by error propagation
%             y_pstd :
%             A_pstd :
%             s_pstd :
%             c_pstd :
%            sigma_r : standard deviation of the background (residual)
%         SE_sigma_r : standard error of sigma_r
%            pval_Ar : p-value of an amplitude vs. background noise test (p > 0.05 -> significant amplitude)
%
%
% Usage for a single-channel img with mask and fixed sigma:
% fitGaussians2D(img, x_v, y_v, 'sigma', sigma_v, 'mask', mask);

% Francois Aguet, March 28 2011 (last modified: August 30 2011)

function pStruct = fitGaussianMixtures2D(img, x, y, A, sigma, c, varargin)

% Parse inputs
ip = inputParser;
ip.CaseSensitive = false;
ip.addRequired('img', @isnumeric);
ip.addRequired('x');
ip.addRequired('y');
ip.addRequired('A');
ip.addRequired('sigma');
ip.addRequired('c');
% ip.addOptional('mode', 'xyAc', @ischar);
ip.addParamValue('Alpha', 0.05, @isscalar);
ip.addParamValue('Mask', [], @islogical);
ip.addParamValue('maxM', 5, @isscalar);
ip.parse(img, x, y, A, sigma, c, varargin{:});

np = length(x);
sigma = ip.Results.sigma;
if numel(sigma)==1
    sigma = sigma*ones(1,np);
end
% mode = ip.Results.mode;
% mode = 'xyAc';
alpha = ip.Results.Alpha;
if ~isempty(ip.Results.Mask)
    labels = bwlabel(ip.Results.Mask);
else
    labels = zeros(size(img));
end

pStruct = struct('x', [], 'y', [], 'A', [], 's', [], 'c', [],...
    'x_pstd', [], 'y_pstd', [], 'A_pstd', [], 's_pstd', [], 'c_pstd', [],...
    'x_init', [], 'y_init', [],...
    'sigma_r', [], 'SE_sigma_r', [], 'RSS', [], 'pval_Ar', [], 'hval_Ar', [], 'hval_AD', []);

xi = round(x);
yi = round(y);
[ny,nx] = size(img);

kLevel = norminv(1-alpha/2.0, 0, 1); % ~2 std above background

iRange = [squeeze(min(min(img))) squeeze(max(max(img)))];

% estIdx = regexpi('xyAsc', ['[' mode ']']);
% estIdx = [1 1 1 0 1];

% initialize pStruct arrays
pStruct.x = cell(1,np);
pStruct.y = cell(1,np);
pStruct.A = cell(1,np);
pStruct.s = cell(1,np);
pStruct.c = cell(1,np);

pStruct.x_pstd = cell(1,np);
pStruct.y_pstd = cell(1,np);
pStruct.A_pstd = cell(1,np);
pStruct.s_pstd = cell(1,np);
pStruct.c_pstd = cell(1,np);

% pStruct.x_init = reshape(xi, [1 np]);
% pStruct.y_init = reshape(yi, [1 np]);
pStruct.x_init = cell(1,np);
pStruct.y_init = cell(1,np);

pStruct.sigma_r = cell(1,np);
pStruct.SE_sigma_r = cell(1,np);
pStruct.RSS = cell(1,np);

pStruct.pval_Ar = cell(1,np);

pStruct.hval_AD = cell(1,np);
pStruct.hval_Ar = cell(1,np);


sigma_max = max(sigma);
w2 = ceil(2*sigma_max);
w3 = ceil(3*sigma_max);
w4 = ceil(4*sigma_max);
nw = 2*w4+1;

% mask template: ring with inner radius w3, outer radius w4
[xm,ym] = meshgrid(-w4:w4);
r = sqrt(xm.^2+ym.^2);
annularMask = zeros(size(r));
annularMask(r<=w4 & r>=w3) = 1;

g = exp(-(-w4:w4).^2/(2*sigma_max^2));
g = g'*g;
g = g(:);

mixtureIndex = 1;
for p = 1:np
    
    % ignore points in border
    if (xi(p)>w4 && xi(p)<=nx-w4 && yi(p)>w4 && yi(p)<=ny-w4)
        
        % label mask
        maskWindow = labels(yi(p)-w4:yi(p)+w4, xi(p)-w4:xi(p)+w4);
        maskWindow(maskWindow==maskWindow(w4+1,w4+1)) = 0;
        
        % estimate background
        cmask = annularMask;
        cmask(maskWindow~=0) = 0;
        window = img(yi(p)-w4:yi(p)+w4, xi(p)-w4:xi(p)+w4);
        if isempty(c)
            c0 = mean(window(cmask==1));
        else
            c0 = c(p);
        end
        
        % set any other components to NaN
        window(maskWindow~=0) = NaN;
        npx = sum(isfinite(window(:)));
        
        % fit
        if isempty(A)
            A0 = max(window(:))-c0;
        else
            A0 = A(p);
        end

        % initial fit with a single Gaussian
        [prm_f, prmStd_f, ~, res_f] = fitGaussian2D(window, [x(p)-xi(p) y(p)-yi(p) A0 sigma(p) c0], 'xyAc');
        prmStd_f = [prmStd_f(1:3) 0 prmStd_f(4)];
        RSS_r = res_f.RSS;
        
        %prm_r = prm_f;
        %prmStd_r = prmStd_f;
        %res_r = res_f;
        
        p_r = 4; % #parameters        
        i = 1;
        
        pval = 0;
        validBounds = true;
        while i<ip.Results.maxM && pval<0.05 && validBounds % models are significantly different
                
            i = i+1;
            prm_r = prm_f;
            prmStd_r = prmStd_f;
            res_r = res_f;
            
            % expanded model
            % new component: initial values given by max. residual point
            [x0 y0] = ind2sub([nw nw], find(RSS_r==max(RSS_r(:)),1,'first'));
            [prm_f, prmStd_f, ~, res_f] = fitGaussianMixture2D(window, [x0 y0 max(res_f.data(:)) prm_r], 'xyAc');
            RSS_f = res_f.RSS;
            p_f = p_r + 3;
            
            % test statistic
            T = (RSS_r-RSS_f)/RSS_f * (npx-p_f-1)/(p_f-p_r);
            pval = 1-fcdf(T,p_f-p_r,npx-p_f-1);
            
            % update reduced model
            p_r = p_f;
            RSS_r = RSS_f;
            
            % restrict radius; otherwise neighboring signals are considered part of mixture
            if min(prm_f(1:3:end-2))<-w2 || max(prm_f(1:3:end-2))>w2 ||...
                    min(prm_f(2:3:end-2))<-w2 || max(prm_f(2:3:end-2))>w2
                validBounds = false;
            end
            
        end
        ng = i-1; % # gaussians in final model
        
        x_est = prm_r(1:3:end-2);
        y_est = prm_r(2:3:end-2);
        A_est = prm_r(3:3:end-2);
        
        % exclude points where localization failed
        if ng>1 || (x_est > -w2 && x_est < w2 && y_est > -w2 && y_est < w2 && A_est<2*diff(iRange))
            pStruct.x{p} = xi(p) + x_est;
            pStruct.y{p} = yi(p) + y_est;
            pStruct.A{p} = A_est;
            % sigma and background offset are identical for all mixture components
            pStruct.s{p} = repmat(prm_r(end-1), [1 ng]);
            pStruct.c{p} = repmat(prm_r(end), [1 ng]);
            
            %stdVect = zeros(1,5);
            %stdVect(estIdx) = prmStd;
            
            pStruct.x_pstd{p} = prmStd_r(1:3:end-2);
            pStruct.y_pstd{p} = prmStd_r(2:3:end-2);
            pStruct.A_pstd{p} = prmStd_r(3:3:end-2);
            pStruct.s_pstd{p} = repmat(prmStd_r(end-1), [1 ng]);
            pStruct.c_pstd{p} = repmat(prmStd_r(end), [1 ng]);
            
            pStruct.x_init{p} = repmat(xi, [1 ng]);
            pStruct.y_init{p} = repmat(yi, [1 ng]);
            
            pStruct.sigma_r{p} = repmat(res_r.std, [1 ng]);
            pStruct.RSS{p} = repmat(res_r.RSS, [1 ng]);
            
            SE_sigma_r = res_r.std/sqrt(2*(npx-1));
            pStruct.SE_sigma_r{p} = repmat(SE_sigma_r, [1 ng]);
            SE_sigma_r = SE_sigma_r * kLevel;
            
            pStruct.hval_AD{p} = repmat(res_r.hAD, [1 ng]);
            
            % H0: A <= k*sigma_r
            % H1: A > k*sigma_r
            for i = 1:ng
                sigma_A = pStruct.A_pstd{p}(i);
                A_est = pStruct.A{p}(i);
                %A_est = prm(3);
                df2 = (npx-1) * (sigma_A.^2 + SE_sigma_r.^2).^2 ./ (sigma_A.^4 + SE_sigma_r.^4);
                scomb = sqrt((sigma_A.^2 + SE_sigma_r.^2)/npx);
                T = (A_est - res_r.std*kLevel) ./ scomb;
                % 1-sided t-test: A_est must be greater than k*sigma_r
                pStruct.pval_Ar{p}(i) = tcdf(-T, df2);
                pStruct.hval_Ar{p}(i) = pStruct.pval_Ar{p}(i) < alpha;
                %pStruct.mask_Ar{p}(i) = sum(A_est*g>res_r.std*kLevel); % # significant pixels
            end
            if ng>1
                pStruct.mixtureIndex{p} = mixtureIndex*ones(1,ng);
                mixtureIndex = mixtureIndex+1;
            else
                pStruct.mixtureIndex{p} = 0;
            end
        end
    end
end

% concatenate cell arrays
fnames = fieldnames(pStruct);
for f = 1:numel(fnames)
    pStruct.(fnames{f}) = [pStruct.(fnames{f}){:}];
end
