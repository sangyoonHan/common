%FITGAUSSIANMIXTURE2D Fit a 2-D Gaussian mixture model to data in a square image window.
%    [prmVect prmStd C res J] = fitGaussianMixture2D(data, prmVect, mode, options)
%
%    Symbols: xp : x-position
%             yp : y-position
%              A : amplitude
%              s : standard deviation
%              c : background
%
%    The origin is defined at the center of the input window.
%
%    Inputs:     data : 2-D image array
%             prmVect : Parameter vector with order: [xp_1 yp_1 A_1 ... xp_n yp_n A_n s c].
%                       The number of triplets [xp yp A] determines the number of Gaussians. 
%                mode : String that defines parameters to be optimized; any among 'xyasc'.
%           {options} : Vector [maxIter eAbs eRel]; max. iterations, tolerances. See GSL documentation.
%
%    Pixels in 'data' that are set to NaN are masked in the optimization.
%
%    Outputs: prmVect : parameter vector
%              prmStd : parameter standard deviations
%                   C : covariance matrix
%                 res : structure with fields:
%                         .data : residuals
%                         .pval : p-value of the Kolmogorov-Smirnov test (normal dist.)
%                         .mean : mean of the residuals
%                         .std  : standard deviation of the residuals
%                   J : Jacobian
%
% Axis conventions: image processing, see meshgrid
% For single Gaussian mixture fitting, fitGaussian2D() is faster.
%
% Example: [prmVect prmStd C res J] = fitGaussian2D(data, [0 0 max(data(:)) 0 0 max(data(:)) 1.5 min(data(:))], 'xyasc');