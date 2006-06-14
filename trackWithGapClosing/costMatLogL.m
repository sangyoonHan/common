function [costMat,noLinkCost,errFlag] = costMatLogL(movieInfo,costMatParams)
%COSTMATLOGL provides a cost matrix for linking features between 2 time points based on amplitude and displacement statistics
%
%SYNOPSIS [costMat,noLinkCost,errFlag] = costMatLogL(movieInfo,trackStats)
%
%INPUT  movieInfo    : A 2x1 array (corresponding to the 2 time points of 
%                      interest) containing the fields:
%             .xCoord     : Image coordinate system x-coordinate of detected
%                           features [x dx] (in pixels).
%             .yCoord     : Image coorsinate system y-coordinate of detected
%                           features [y dy] (in pixels).
%             .amp        : Amplitudes of PSFs fitting detected features [a da].
%       costMatParams: Structure with the fields:
%             .trackStats : Structure with the following fields:
%                   .dispSqLambda: Parameter of the exponential distribution
%                                  that describes the displacement of a feature
%                                  between two consecutive frames.
%                   .ampDiffStd  : Standard deviation of the change in a feature's 
%                                  amplitude between consecutive time points.
%             .cutoffProbD: Cumulative probability of a square diplacement
%                           beyond which linking is not allowed.
%             .cutoffProbA: Cumulative probability of an amplitude
%                           difference beyond which linking is not allowed.
%             .noLnkPrctl : Percentile used to calculate the cost of
%                           linking a feature to nothing. Use -1 if you do
%                           not want to calculate this cost.
%
%OUTPUT costMat      : Cost matrix.
%       noLinkCost   : Cost of linking a feature to nothing, as derived
%                      from the distribution of costs.
%       errFlag      : 0 if function executes normally, 1 otherwise.
%
%REMARKS The cost for linking feature i in time point t to feature j 
%in time point t+1 is given by -log[p(dI)p(dispSq)], where 
%dI = I(j;t+1) - I(i,t) is assumed to be normally distributed with mean 0
%and standard deviation ampDiffStd (supplied by user), and 
%dispSq = square of distance between feature i at t and feature j at t+1
%is assumed to be exponentially distributed with parameter dispSqLambda
%(supplied by user).
%
%Khuloud Jaqaman, March 2006

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

costMat = [];
noLinkCost = [];
errFlag = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Input
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%check whether correct number of input arguments was used
if nargin ~= nargin('costMatLogL')
    disp('--costMatLogL: Incorrect number of input arguments!');
    errFlag  = 1;
    return
end

dispSqLambda = costMatParams.trackStats.dispSqLambda(1);
ampDiffStd = costMatParams.trackStats.ampDiffStd(1);
cutoffProbD = costMatParams.cutoffProbD;
cutoffProbA = costMatParams.cutoffProbA;
noLnkPrctl = costMatParams.noLnkPrctl;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Cost matrix calculation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%get the maximum squared displacement that allows linking 2 features
maxDispSq = expinv(cutoffProbD,dispSqLambda);

%find the maximum squared amplitude change that allows linking 2 features
maxAmpDiffSq = (norminv(cutoffProbA,0,ampDiffStd)).^2;

%get number of features in the 2 time points
n = movieInfo(1).num;
m = movieInfo(2).num;

%replicate the x,y-coordinates and amplitude at the 2 time points to get n-by-m matrices
x1 = repmat(movieInfo(1).xCoord(:,1),1,m);
y1 = repmat(movieInfo(1).yCoord(:,1),1,m);
a1 = repmat(movieInfo(1).amp(:,1),1,m);
x2 = repmat(movieInfo(2).xCoord(:,1)',n,1);
y2 = repmat(movieInfo(2).yCoord(:,1)',n,1);
a2 = repmat(movieInfo(2).amp(:,1)',n,1);

%calculate the squared displacement of features from t to t+1
dispSq = (x1-x2).^2 + (y1-y2).^2;
dispSq(find(dispSq>maxDispSq)) = NaN;

%calculate the squared change in the amplitude of features from t to t+1
ampDiffSq = (a1 - a2).^2;
ampDiffSq(find(ampDiffSq>maxAmpDiffSq)) = NaN;

%calculate the cost matrix
costMat = ampDiffSq/2/ampDiffStd^2 + dispSqLambda*dispSq;

%determine noLinkCost
if noLnkPrctl ~= -1
    noLinkCost = prctile(costMat(:),noLnkPrctl);
end

%replace NaN, indicating pairs that cannot be linked, with -1
costMat(find(isnan(costMat))) = -1;


%%%%% ~~ the end ~~ %%%%%

