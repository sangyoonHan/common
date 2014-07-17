function [intensityHist,numModes,allModeMean,allModeStd,allModeFrac,...
    numFeatures,errFlag] = singleFluoroAnalysis(movieInfo,movieName,...
    startFrame,endFrame,alpha,variableMean,variableStd,numModeMinMax,...
    plotResults,logData,modeParamIn)
%SINGLEFLUOROANALYSIS looks for peaks in the intensity histogram in each frame and plots their characteristics.
%
%SYNOPSIS [intensityHist,numModes,allModeMean,allModeStd,allModeFrac,...
%    numFeatures,errFlag] = singleFluoroAnalysis(movieInfo,movieName,...
%    startFrame,endFrame,alpha,variableMean,variableStd,numModeMinMax,...
%    plotResults,logData,modeParamIn)
%
%INPUT  
%   Mandatory
%       movieInfo    : Array of size equal to the number of frames
%                      in movie, containing the fields:
%             .xCoord      : Image coordinate system x-coordinates of detected
%                            features (in pixels). 1st column for
%                            value and 2nd column for standard deviation.
%             .yCoord      : Image coordinate system y-coordinates of detected
%                            features (in pixels). 1st column for
%                            value and 2nd column for standard deviation.
%                            Optional. Skipped if problem is 1D. Default: zeros.
%             .zCoord      : Image coordinate system z-coordinates of detected
%                            features (in pixels). 1st column for
%                            value and 2nd column for standard deviation.
%                            Optional. Skipped if problem is 1D or 2D. Default: zeros.
%             .amp         : Amplitudes of PSFs fitting detected features. 
%                            1st column for values and 2nd column 
%                            for standard deviations.
%   Optional
%       movieName    : Name of movie. Needed to put as title of plot if plotting.
%                      Default: 'movie1'.
%       startFrame   : Frame number at which to start analysis.
%                      Default: 1.
%       endFrame     : Frame number at which to end analysis.
%                      Default: Last frame in movie.
%       alpha        : Alpha-value for the statistical test that compares the
%                      fit of n+1 Gaussians to the fit of n Gaussians.
%                      Default: 0.05.
%       variableMean : 0 if assuming the fixed relationship
%                      (mean of nth Gaussian) = n * (mean of 1st Gaussian).
%                      1 if there is no relationship between the means of
%                      different Gaussians.
%                      Default: 0.
%       variableStd  : 0 if assuming that all Gaussians have the same
%                      standard deviation. 1 if there is no relationship 
%                      between the standard deviations of different
%                      Gaussians, 2 if assuming the relationship 
%                      (std of nth Gaussian) = sqrt(n) * (std of 1st Gaussian). 
%                      variableStd can equal 2 only if variableMean is 0.
%                      Default: 0.
%       numModeMinMax: Vector with minimum and maximum number of modes
%                      (Gaussian or log-normal) to fit. 
%                      Default: [1 9].
%                      If only one value is input, it will be taken as the
%                      maximum.
%       plotResults  : 1 if results are to be plotted, 0 otherwise.
%                      Default: 1.
%       logData      : 1 to fit intensity distributions with log-normal, 0
%                      to fit with normal.
%                      Default: 0.
%       modeParamIn :  Matrix with number of rows equal to number of
%                      modes and two columns indicating the mean/M
%                      (Gaussian/lognormal) and standard deviation/S
%                      (Gaussian/lognormal) of each mode. If input, the
%                      specified mode parameters are used, and only the mode
%                      amplitudes are determined by data fitting. In this
%                      case, the input alpha, variableMean, variableStd
%                      and numModeMinMax are not used.
%                      Optional. Default: [].
%
%OUTPUT intensityHist    : Array of structures with field modeParam as outputed by
%                          fitHistWithGaussians for each analyzed frame.
%                          When logData = 1, these are the log-normal
%                          parameters M and S (i.e. not the mean and std).
%       numModes         : Number of intensity modes detected in each
%                          analyzed frame.
%       allModeMean      : Means of fitted Gaussians in each analyzed
%                          frame. When logData = 1, this will be the mean
%                          of the lognormal distribution, not the
%                          distribution parameter M. See Remarks for
%                          formula.
%       allModeStd       : Standard deviations of fitted Gaussians in
%                          each analyzed frame. When logData = 1, this will
%                          be the stanrd deviation of the lognormal
%                          distribution, not the distribution parameter S.
%                          See Remarks for formula.
%       allModeFrac      : Fraction of each mode among the data in each
%                          analyzed frame.
%       numFeatures      : Number of detected features in each analyzed
%                          frame. NaN indicates frame hasn't been analyszed.
%       errFlag          : 0 if function executes normally, 1 otherwise;
%
%REMARKS Interconversion between log-normal parameters M and S, and mean and
%and standard deviation of distribution mu and sigma:
%
% mu = exp(M+S^2/2) & standard deviation: sigma^2 = exp(S^2+2M)*(exp(S^2)-1)
%
% Inverse: 
% M = ln(mu^2/sqrt(sigma^2+mu^2)) & S^2 = ln(sigma^2/mu^2+1)
%
%Khuloud Jaqaman, April 2007

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

errFlag = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Input
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%check whether correct number of input arguments was used
if nargin < 1
    disp('--singleFluoroAnalysis: Function needs at least 1 input argument!');
    return
end

%find number of frames in movie
numFrames = length(movieInfo);

%assign default values of optional input variables
movieName_def = 'movie1';
startFrame_def = 1;
endFrame_def = numFrames;
alpha_def = 0.05;
variableMean_def = 0;
variableStd_def = 0;
numModeMinMax_def = [1 9];
plotResults_def = 1;
logData_def = 0;

%check movieName
if nargin < 2 || isempty(movieName)
    movieName = movieName_def;
end    

%check startFrame
if nargin < 3 || isempty(startFrame)
    startFrame = startFrame_def;
else
    if startFrame < 1 || startFrame > numFrames
        disp('--singleFluoroAnalysis: "startFrame" should be between 1 and number of frames in movie!');
        errFlag = 1;
    end
end

%check endFrame
if nargin < 4 || isempty(endFrame)
    endFrame = endFrame_def;
else
    if endFrame < startFrame || endFrame > numFrames
        disp('--singleFluoroAnalysis: "endFrame" should be between "startFrame" and number of frames in movie!');
        errFlag = 1;
    end
end

%check alpha
if nargin < 5 || isempty(alpha)
    alpha = alpha_def;
else
    if alpha < 0 || alpha > 1
        disp('--singleFluoroAnalysis: "alpha" should be between 0 and 1!');
        errFlag = 1;
    end

end

%check variableMean
if nargin < 6 || isempty(variableMean)
    variableMean = variableMean_def;
else
    if ~any(variableMean == [0,1])
        disp('--singleFluoroAnalysis: "variableMean" should be 0 or 1!');
        errFlag = 1;
    end
end

%check variableStd
if nargin < 7 || isempty(variableStd)
    variableStd = variableStd_def;
else
    if ~any(variableStd == [0,1,2])
        disp('--singleFluoroAnalysis: "variableStd" should be 0, 1 or 2!');
        errFlag = 1;
    end
end

%check numModeMinMax
if nargin < 8 || isempty(numModeMinMax)
    numModeMinMax = numModeMinMax_def;
else
    if any(numModeMinMax < 1)
        disp('--singleFluoroAnalysis: "numModeMinMax" should be at least 1!');
        errFlag = 1;
    end
end

%check plotResults
if nargin < 9 || isempty(plotResults)
    plotResults = plotResults_def;
else
    if ~any(plotResults == [0,1])
        disp('--singleFluoroAnalysis: "plotResults" should be 0 or 1!');
        errFlag = 1;
    end
end

%check logData
if nargin < 10 || isempty(logData)
    logData = logData_def;
else
    if ~any(logData == [0,1])
        disp('--singleFluoroAnalysis: "logData" should be 0 or 1!');
        errFlag = 1;
    end
end
if logData && (variableMean==1&&variableStd~=1 || variableStd==1&&variableMean~=1)
    disp('--fitHistWithGaussians: For log-normal fit,  mean and std must be either both variable or both constrained. Exiting.')
    return
end

%check input modes
if nargin < 11 || isempty(modeParamIn)
    modeParamIn = [];
else
    numModeMinMax = size(modeParamIn,1)*[1 1];
end

%exit if there are problem in input variables
if errFlag
    disp('--singleFluoroAnalysis: Please fix input data!');
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Intensity analysis
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%get number of features in each frame
numFeatures = NaN*ones(1,numFrames);
for i = startFrame : endFrame
    if ~isempty(movieInfo(i).amp)
        numFeatures(i) = length(movieInfo(i).amp(:,1));
    else
        numFeatures(i) = 0;
    end
end

%fit the amplitude distribution in each frame with Gaussians or log-normal
%don't consider frame if it has less than 10 features
intensityHist(1:numFrames) = struct('modeParam',[]);
for i = startFrame : endFrame
    if numFeatures(i) >= 10
        [~,~,modeParam,errFlag] = ...
            fitHistWithGaussians(movieInfo(i).amp(:,1),alpha,variableMean,...
            variableStd,0,numModeMinMax,2,[],logData,modeParamIn);
        intensityHist(i).modeParam = modeParam;
    end
end

%get number of modes found in each frame
numModes = NaN*ones(1,numFrames);
for i = startFrame : endFrame
    if ~isempty(intensityHist(i).modeParam)
        numModes(i) = size(intensityHist(i).modeParam,1);
    end
end
maxnumModes = max(numModes);

%get mean, std and fraction of the modes in each frame
allModeMean = NaN*ones(maxnumModes,numFrames);
allModeStd = NaN*ones(maxnumModes,numFrames);
allModeFrac = NaN*ones(maxnumModes,numFrames);
for i = startFrame : endFrame
    if ~isempty(intensityHist(i).modeParam)
        allModeMean(1:numModes(i),i) = intensityHist(i).modeParam(:,1);
        allModeStd(1:numModes(i),i) = intensityHist(i).modeParam(:,2);
        allModeFrac(1:numModes(i),i) = intensityHist(i).modeParam(:,4)/sum(intensityHist(i).modeParam(:,4));
    end
end
if logData
    actualMean = exp(allModeMean+allModeStd.^2/2);
    actualStd = sqrt(exp(allModeStd.^2+2*allModeMean).*(exp(allModeStd.^2)-1));
    allModeMean = actualMean;
    allModeStd = actualStd;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Plotting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%plot results
if plotResults
    
    %open new figure window
    figure('Name',movieName,'NumberTitle','off');

    %plot number of features per frame in 1st sub-plot
    subplot(4,1,1)
    hold on;
    if any(~isnan(numFeatures))
        plot(numFeatures,'k');
        axis([0 numFrames 0 1.1*max(numFeatures)]);
    end
    title(['Number of objects for ' movieName]);

    %plot number of modes per frame in 2nd sub-plot
    subplot(4,1,2)
    hold on;
    if any(~isnan(numModes))
        plot(numModes,'k')
        axis([0 numFrames 0 max(numModes)+1]);
    end
    title('Number of modes');
    
    %plot mean and std of first fitted Gaussian in 3rd sub-plot
    subplot(4,1,3)
    hold on
    if any(~isnan(allModeMean(:)))
        plot(allModeMean(1,:),'k')
        plot(allModeStd(1,:),'r')
        axis([0 numFrames 0 1.1*max([allModeMean(1,:) allModeStd(1,:)])]);
    end
    title('Mean (black) and std (red) of 1st mode');
    
    %plot fraction of each mode in 4th sub-plot
    subplot(4,1,4)
    hold on
    if any(~isnan(allModeFrac(:)))
        plot(allModeFrac(1,:),'k')
        if maxnumModes > 1
            plot(allModeFrac(2,:),'r')
            if maxnumModes > 2
                plot(allModeFrac(3,:),'g')
                if maxnumModes > 3
                    plot(allModeFrac(4,:),'b')
                end
            end
        end
        axis([0 numFrames 0 1.1*max(allModeFrac(:))]);
    end
    title('Mode fraction (1 black, 2 red, 3 green, 4 blue)');
    xlabel('Frame number');
    
end %(if plotRes)


%%%%% ~~ the end ~~ %%%%%
