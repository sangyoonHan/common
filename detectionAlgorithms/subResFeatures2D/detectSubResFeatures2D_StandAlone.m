function [movieInfo,exceptions,localMaxima,background,psfSigma] = ...
    detectSubResFeatures2D_StandAlone(movieParam,detectionParam,saveResults)
%DETECTSUBRESFEATURES2D_STANDALONE detects subresolution features in a series of images
%
%SYNOPSIS [movieInfo,exceptions,localMaxima,background,psfSigma] = ...
%    detectSubResFeatures2D_StandAlone(movieParam,detectionParam,saveResults)
%
%INPUT  movieParam    : Structure with fields
%           .imageDir     : Directory where images are stored.
%           .filenameBase : Filename base.
%           .firstImageNum: Numerical index of first image in movie.
%           .lastImageNum : Numerical index of last image in movie.
%           .digits4Enum  : Number of digits used to enumerate frames.
%       detectionParam: Structure with fields
%           .psfSigma     : Initial guess for standard deviation of point
%                           spread function (in pixels).
%           .testAlpha    : Alpha-values for statistical tests in
%                           detectSubResFeatures2D.
%                           (See detectSubResFeatures2D for details).
%                           Optional. Default values 0.05.s
%           .visual       : 1 if user wants to view results; 0 otherwise.
%                           Optional. Default: 0.
%           .doMMF        : 1 if user wants to do mixture-model fitting, 0
%                           otherwise.
%                           Optional. Default: 1.
%           .bitDepth     : Camera bit depth.
%                           Optional. Default: 16.
%           .alphaLocMax  : Alpha value for statistical test in local maxima
%                           detection.
%                           Optional. default: 0.05.
%                           --- alphaLocMax must be a row vector if
%                           integWindow is a row vector. See description of
%                           integWindow below.
%           .numSigmaIter : Maximum number of iterations to perform when
%                           trying to estimate PSF sigma. Input 0 for no
%                           estimation.
%                           Optional. Default: 10.
%           .integWindow  : Number of frames on each side of a frame
%                           used for time integration.
%                           Optional. Default: 0.
%                           --- integWindow can be a row vector, in which
%                           case alphaLocMax should be a row vector of the
%                           same length. When integWindow is a row vector,
%                           the initial local maxima detection is done by
%                           using all specified integration windows.
%       saveResults   : 0 if no saving is requested.
%                       If saving is requested, structure with fields:
%           .dir          : Directory where results should be saved.
%                           Optional. Default: current directory.
%           .filename     : Name of file where results should be saved.
%                           Optional. Default: detectedFeatures.
%                       Whole structure optional.
%
%       All optional variables can be entered as [] to use default values.
%
%OUTPUT movieInfo     : Structure array of length = number of frames in
%                       movie, containing the fields:
%             .xCoord    : Image coordinate system x-coordinate of detected
%                          features [x dx] (in pixels).
%             .yCoord    : Image coordinate system y-coordinate of detected
%                          features [y dy] (in pixels).
%             .amp       : Amplitudes of PSFs fitting detected features [a da].
%       exceptions    : Structure with fields:
%             .emptyFrames: Array indicating frames where no features were
%                           detected.
%             .framesFailedMMF: Array indicating frames where mixture-model
%                               fitting failed.
%             .framesFailedLocMax: Array indicating frames where initial
%                                  detection of local maxima failed.
%       localMaxima   : Structure array of length = number of frames in
%                       movie, containing the field "cands", which is a
%                       structure array of length = number of local maxima
%                       in each frame, containing the fields:
%             .IBkg       : Mean background intensity around local maximum.
%             .Lmax       : Position of local maximum.
%             .amp        : Amplitude of local maximum.
%             .pValue     : P-value of local maximum in statistical test
%                           determining its significance.
%       background    : Structure with fields:
%             .meanRawLast5: Mean background intensity in raw movie as
%                            calculated from the last 5 frames.
%             .stdRawLast5 : Standard deviation of background intensity in
%                            raw movie as calculated from the 5 frames.
%             .meanIntegFLast1: Mean background intensity in last frame of
%                               integrated movie.
%             .stdIntegFLast1 : Standard deviation of background intensity
%                               in last frame of integrated movie.
%             .meanIntegFFirst1: Mean background intensity in first frame of
%                                integrated movie.
%             .stdIntegFFirst1 : Standard deviation of background intensity
%                                in first frame of integrated movie.
%       psfSigma      : Standard deviation of point spread function as
%                       estimated from fitting to local maxima in the movie.
%       signal2noiseRatio: Number of features - by - number of frames
%                       array showing signal to noise ratio of all
%                       features in all frames (SNR = signal amplitude
%                       above background / local background std). - WILL
%                       IMPLEMENT SOON.
%       errFlag       : 0 if function executes normally, 1 otherwise.
%
%Khuloud Jaqaman, September 2007

%% Output

movieInfo = [];
exceptions = [];
localMaxima = [];
background = [];
psfSigma = [];

%% Input + initialization

%check whether correct number of input arguments was used
if nargin < 2
    disp('--detectSubResFeatures2D_StandAlone: Incorrect number of input arguments!');
    return
end

%get movie parameters
imageDir = movieParam.imageDir;
filenameBase = movieParam.filenameBase;
firstImageNum = movieParam.firstImageNum;
lastImageNum = movieParam.lastImageNum;
digits4Enum = movieParam.digits4Enum;

%get initial guess of PSF sigma
psfSigma = detectionParam.psfSigma;

%get statistical test alpha values
if ~isfield(detectionParam,'testAlpha') || isempty(detectionParam.testAlpha)
    testAlpha = struct('alphaR',0.05,'alphaA',0.05,'alphaD',0.05,'alphaF',0.05);
else
    testAlpha = detectionParam.testAlpha;
end

%get visualization option
if ~isfield(detectionParam,'visual') || isempty(detectionParam.visual)
    visual = 0;
else
    visual = detectionParam.visual;
end

%check whether to do MMF
if ~isfield(detectionParam,'doMMF') || isempty(detectionParam.doMMF)
    doMMF = 1;
else
    doMMF = detectionParam.doMMF;
end

%get camera bit depth
if ~isfield(detectionParam,'bitDepth') || isempty(detectionParam.bitDepth)
    bitDepth = 16;
else
    bitDepth = detectionParam.bitDepth;
end

%get alpha-value for local maxima detection
if ~isfield(detectionParam,'alphaLocMax') || isempty(detectionParam.alphaLocMax)
    alphaLocMax = 0.05;
else
    alphaLocMax = detectionParam.alphaLocMax;
end
numAlphaLocMax = length(alphaLocMax);

%check whether to estimate PSF sigma from the data
if ~isfield(detectionParam,'numSigmaIter') || isempty(detectionParam.numSigmaIter)
    numSigmaIter = 10;
else
    numSigmaIter = detectionParam.numSigmaIter;
end

%get integration time window
if ~isfield(detectionParam,'integWindow')
    integWindow = 0;
else
    integWindow = detectionParam.integWindow;
end
numIntegWindow = length(integWindow);

%make sure that alphaLocMax is the same size as integWindow
if numIntegWindow > numAlphaLocMax
    alphaLocMax = [alphaLocMax ...
        alphaLocMax(1)*ones(1,numIntegWindow-numAlphaLocMax)];
end

%determine where to save results
if nargin < 3 || isempty(saveResults) %if nothing was input
    saveResDir = pwd;
    saveResFile = 'detectedFeatures';
    saveResults.dir = pwd;
else
    if isstruct(saveResults)
        if ~isfield(saveResults,'dir') || isempty(saveResults.dir)
            saveResDir = pwd;
        else
            saveResDir = saveResults.dir;
        end
        if ~isfield(saveResults,'filename') || isempty(saveResults.filename)
            saveResFile = 'detectedFeatures';
        else
            saveResFile = saveResults.filename;
        end
    else
        saveResults = 0;
    end
end

%store the string version of the numerical index of each image
enumString = getStringIndx(digits4Enum);

%initialize some variables
emptyFrames = [];
framesFailedLocMax = [];
framesFailedMMF = [];

%turn warnings off
warningState = warning('off','all');

%% General image information

%get image indices and number of images
imageIndx = firstImageNum : lastImageNum;
numImagesRaw = lastImageNum - firstImageNum + 1; %raw images
numImagesInteg = repmat(numImagesRaw,1,numIntegWindow) - 2 * integWindow; %integrated images

%read first image and get image size
if exist([imageDir filenameBase enumString(imageIndx(1),:) '.tif'],'file')
    imageTmp = imread([imageDir filenameBase enumString(imageIndx(1),:) '.tif']);
else
    disp('First image does not exist! Exiting ...');
    return
end
[imageSizeX,imageSizeY] = size(imageTmp);
clear imageTmp

%check which images exist and which don't
imageExists = zeros(numImagesRaw,1);
for iImage = 1 : numImagesRaw
    if exist([imageDir filenameBase enumString(imageIndx(iImage),:) '.tif'],'file')
        imageExists(iImage) = 1;
    end
end

%calculate background properties at movie end
last5start = max(numImagesRaw-4,1);
i = 0;
imageLast5 = NaN(imageSizeX,imageSizeY,5);
for iImage = last5start : numImagesRaw
    i = i + 1;
    if imageExists(iImage)
        imageLast5(:,:,i) = imread([imageDir filenameBase enumString(imageIndx(iImage),:) '.tif']);
    end
end
imageLast5 = double(imageLast5) / (2^bitDepth-1);
imageLast5(imageLast5==0) = NaN;
[bgMeanRaw,bgStdRaw] = spatialMovAveBG(imageLast5,imageSizeX,imageSizeY);

%% Local maxima detection

%initialize output structure
localMaxima = repmat(struct('cands',[]),numImagesRaw,1);

for iWindow = 1 : numIntegWindow
    
    %initialize progress text
    progressText(0,['Detecting local maxima with integration window = ' num2str(integWindow(iWindow))]);
    
    for iImage = 1 : numImagesInteg(iWindow)
        
        %store raw images in array
        imageRaw = NaN(imageSizeX,imageSizeY,1+2*integWindow(iWindow));
        for jImage = 1 : 1 + 2*integWindow(iWindow)
            if imageExists(jImage+iImage-1)
                imageRaw(:,:,jImage) = double(imread([imageDir filenameBase enumString(imageIndx(jImage+iImage-1),:) '.tif']));
            end
        end
        
        %replace zeros with NaNs
        %zeros result from cropping that leads to curved boundaries
        imageRaw(imageRaw==0) = NaN;
        
        %normalize images
        imageRaw = imageRaw / (2^bitDepth-1);
        
        %integrate images
        imageInteg = nanmean(imageRaw,3);
        
        %filter integrated image
        imageIntegF = Gauss2D(imageInteg,1);
        
        %use robustMean to get mean and std of background intensities
        %in this method, the intensities of actual features will look like
        %outliers, so we are effectively getting the mean and std of the background
        %account for possible spatial heterogeneity by taking a spatial moving
        %average
        
        %get integrated image background noise statistics
        [bgMeanInteg,bgStdInteg] = ...
            spatialMovAveBG(imageInteg,imageSizeX,imageSizeY);
        
        background = [];
        
        %clear some variables
        clear imageInteg
        
        try
            
            %call locmax2d to get local maxima in filtered image
            fImg = locmax2d(imageIntegF,[3 3],1);
            
            %get positions and amplitudes of local maxima
            [localMaxPosX,localMaxPosY,localMaxAmp] = find(fImg);
            localMax1DIndx = find(fImg(:));
            
            %get background values corresponding to local maxima
            bgMeanInteg1 = bgMeanInteg;
            bgMeanMaxF = bgMeanInteg1(localMax1DIndx);
            bgStdInteg1 = bgStdInteg;
            bgStdMaxF = bgStdInteg1(localMax1DIndx);
            bgMeanMax = bgMeanRaw(localMax1DIndx);
            
            %calculate the p-value corresponding to the local maxima's amplitudes
            %assume that background intensity in integrated image is normally
            %distributed with mean bgMeanMaxF and standard deviation bgStdMaxF
            pValue = 1 - normcdf(localMaxAmp,bgMeanMaxF,bgStdMaxF);
            
            %retain only those maxima with significant amplitude
            keepMax = find(pValue < alphaLocMax(iWindow));
            localMaxPosX = localMaxPosX(keepMax);
            localMaxPosY = localMaxPosY(keepMax);
            localMaxAmp = localMaxAmp(keepMax);
            bgMeanMax = bgMeanMax(keepMax);
            pValue = pValue(keepMax);
            numLocalMax = length(keepMax);
            
            %construct cands structure
            if numLocalMax == 0 %if there are no local maxima
                
                cands = [];
                %                 emptyFrames = [emptyFrames; iImage+integWindow]; %#ok<AGROW>
                
            else %if there are local maxima
                
                %define background mean and status
                cands = repmat(struct('status',1,'IBkg',[],...
                    'Lmax',[],'amp',[],'pValue',[]),numLocalMax,1);
                
                %store maxima positions, amplitudes and p-values
                for iMax = 1 : numLocalMax
                    cands(iMax).IBkg = bgMeanMax(iMax);
                    cands(iMax).Lmax = [localMaxPosX(iMax) localMaxPosY(iMax)];
                    cands(iMax).amp = localMaxAmp(iMax);
                    cands(iMax).pValue = pValue(iMax);
                end
                
            end
            
            %add the cands of the current image to the rest - this is done
            %for the raw images, not the integrated ones
            localMaxima(iImage+integWindow(iWindow)).cands = ...
                [localMaxima(iImage+integWindow(iWindow)).cands; cands];
            
        catch %#ok<CTCH>
            
            %             %if local maxima detection fails, make cands empty
            %             localMaxima(iImage+integWindow).cands = [];
            %
            %             %add this frame to the array of frames with failed local maxima
            %             %detection and to the array of empty frames
            %             framesFailedLocMax = [framesFailedLocMax; iImage+integWindow]; %#ok<AGROW>
            %             emptyFrames = [emptyFrames; iImage+integWindow]; %#ok<AGROW>
            
        end
        
        %display progress
        progressText(iImage/numImagesInteg(iWindow),['Detecting local maxima with integration window = ' num2str(integWindow(iWindow))]);
        
    end %(for iImage = 1 : numImagesInteg(iWindow))
    
    %assign local maxima for frames left out due to time integration
    for iImage = 1 : integWindow(iWindow)
        localMaxima(iImage).cands = [localMaxima(iImage).cands; ...
            localMaxima(integWindow(iWindow)+1).cands];
    end
    for iImage = numImagesRaw-integWindow(iWindow)+1 : numImagesRaw
        localMaxima(iImage).cands = [localMaxima(iImage).cands; ...
            localMaxima(end-integWindow(iWindow)).cands];
    end
    
    % if any(emptyFrames==integWindow(iWindow)+1)
    %     emptyFrames = [emptyFrames; (1:integWindow)'];
    % end
    % if any(emptyFrames==numImagesRaw-integWindow)
    %     emptyFrames = [emptyFrames; (numImagesRaw-integWindow+1:numImagesRaw)'];
    % end
    % if any(framesFailedLocMax==integWindow+1)
    %     framesFailedLocMax = [framesFailedLocMax; (1:integWindow)'];
    % end
    % if any(framesFailedLocMax==numImagesRaw-integWindow)
    %     framesFailedLocMax = [framesFailedLocMax; (numImagesRaw-integWindow+1:numImagesRaw)'];
    % end
    
end %(for iWindow = 1 : numIntegWindow)

%delete whatever local maxima were found in the frames that don't exist,
%because they are clearly an artifact of time-integration
for iFrame = (find(imageExists==0))'
    localMaxima(iFrame).cands = [];
end

%go over all frames, remove redundant cands, and register empty frames
progressText(0,'Removing redundant local maxima');
for iImage = 1 : numImagesRaw
    
    %get the cands of this frame
    candsCurrent = localMaxima(iImage).cands;
    
    %if there are no cands, register that this is an empty frame
    if isempty(candsCurrent)
        
        emptyFrames = [emptyFrames; iImage]; %#ok<AGROW>
        
    else
        
        %get the local maxima positions in this frame
        maxPos = vertcat(candsCurrent.Lmax);
        
        %find the unique local maxima positions
        [~,indxUnique] = unique(maxPos,'rows');
        
        %keep only these unique cands
        candsCurrent = candsCurrent(indxUnique);
        maxPos = vertcat(candsCurrent.Lmax);
        
        %if there is more than one surviving cand
        if size(maxPos,1) > 1
            
            %remove cands that are closer than 2*psfSigma to each other ...
            
            %first do that by clustering the cands ...
            
            %calculate the distances between cands
            y = pdist(maxPos);
            
            %get the linkage between cands using maximum distance
            Z = linkage(y,'complete');
            
            %cluster the cands and keep only 1 cand from each cluster
            T = cluster(Z,'cutoff',2*psfSigma,'criterion','distance');
            [~,cands2keep] = unique(T);
            
            %update list of cands
            candsCurrent = candsCurrent(cands2keep);
            maxPos = vertcat(candsCurrent.Lmax);
            
            %then refine that by removing cands one by one ...
            
            %calculate the distances between surviving cands
            distBetweenCands = createDistanceMatrix(maxPos,maxPos);
            
            %find the minimum distance for each cand
            distBetweenCandsSort = sort(distBetweenCands,2);
            distBetweenCandsSort = distBetweenCandsSort(:,2:end);
            minDistBetweenCands = distBetweenCandsSort(:,1);
            
            %find the minimum minimum distance
            minMinDistBetweenCands = min(minDistBetweenCands);
            
            %if this distance is smaller than 2*psfSigma, remove the
            % maximum with smallest average distance to its neighbors
            while minMinDistBetweenCands <= (2 * psfSigma)
                
                %find the cands involved
                candsInvolved = find(distBetweenCandsSort(:,1) == minMinDistBetweenCands);
                
                %determine which one of them has the smallest average distance
                %to the other cands
                aveDistCands = mean(distBetweenCandsSort(candsInvolved,:),2);
                cand2remove = candsInvolved(aveDistCands==min(aveDistCands));
                cands2keep = setdiff((1:size(maxPos,1))',cand2remove(1));
                
                %remove it from the list of cands
                candsCurrent = candsCurrent(cands2keep);
                maxPos = vertcat(candsCurrent.Lmax);
                
                %repeat the minimum distance calculation
                if size(maxPos,1) > 1
                    distBetweenCands = createDistanceMatrix(maxPos,maxPos);
                    distBetweenCandsSort = sort(distBetweenCands,2);
                    distBetweenCandsSort = distBetweenCandsSort(:,2:end);
                    minDistBetweenCands = distBetweenCandsSort(:,1);
                    minMinDistBetweenCands = min(minDistBetweenCands);
                else
                    minMinDistBetweenCands = 3 * psfSigma;
                end
                
            end %(while minMinDistBetweenCands <= (2 * psfSigma))
            
        end %(if size(maxPos,1) > 1)
        
        localMaxima(iImage).cands = candsCurrent;
        
    end
    
    %display progress
    progressText(iImage/numImagesRaw,'Removing redundant local maxima');
    
end

%make a list of images that have local maxima
goodImages = setxor(1:numImagesRaw,emptyFrames);
numGoodImages = length(goodImages);

%clear some variables
clear ImageIntegF

%% PSF sigma estimation

if numSigmaIter
    
    %specify which parameters to fit for sigma estimation
    fitParameters = [{'X1'} {'X2'} {'A'} {'Sxy'} {'B'}];
    
    %store original input sigma
    psfSigmaIn = psfSigma;
    
    %give a dummy value for psfSigma0 and acceptCalc to start while loop
    psfSigma0 = 0;
    acceptCalc = 1;
    
    %initialize variable counting number of iterations
    numIter = 0;
    
    %iterate as long as estimated sigma is larger than initial sigma
    while numIter <= numSigmaIter && acceptCalc && ((psfSigma-psfSigma0)/psfSigma0 > 0.05)
        
        %add one to number of iterations
        numIter = numIter + 1;
        
        %save input PSF sigma in new variable and empty psfSigma for estimation
        psfSigma0 = psfSigma;
        psfSigma = [];
        
        %calculate some numbers that get repeated many times
        psfSigma5 = ceil(5*psfSigma0);
        
        %initialize progress display
        switch numIter
            case 1
                progressText(0,'Estimating PSF sigma');
            otherwise
                progressText(0,'Repeating PSF sigma estimation');
        end
        
        %go over the first 50 good images and find isolated features
        images2use = goodImages(1:min(50,numGoodImages));
        images2use = setdiff(images2use,1:integWindow);
        for iImage = images2use
            
            %read raw image
            imageRaw = imread([imageDir filenameBase enumString(imageIndx(iImage),:) '.tif']);
            imageRaw = double(imageRaw) / (2^bitDepth-1);
            
            %get feature positions and amplitudes and average background
            featPos = vertcat(localMaxima(iImage).cands.Lmax);
            featAmp = vertcat(localMaxima(iImage).cands.amp);
            featBG  = vertcat(localMaxima(iImage).cands.IBkg);
            featPV  = vertcat(localMaxima(iImage).cands.pValue);
            
            %retain only features that are more than 5*psfSigma0 away from boundaries
            feat2use = find(featPos(:,1) > psfSigma5 & ...
                featPos(:,1) < imageSizeX - psfSigma5 & ...
                featPos(:,2) > psfSigma5 & featPos(:,2) < imageSizeY - psfSigma5);
            featPos = featPos(feat2use,:);
            featAmp = featAmp(feat2use);
            featBG = featBG(feat2use);
            featPV = featPV(feat2use);
            
            %if there is more than one feature ...
            if length(feat2use) > 1
                
                %find nearest neighbor distances
                nnDist = createDistanceMatrix(featPos,featPos);
                nnDist = sort(nnDist,2);
                nnDist = nnDist(:,2);
                
                %retain only features whose nearest neighbor is more than 10*psfSigma0
                %away
                feat2use = find(nnDist > ceil(10*psfSigma0));
                featPos = featPos(feat2use,:);
                featAmp = featAmp(feat2use);
                featBG = featBG(feat2use);
                featPV = featPV(feat2use);
                
                %retain only features with pValue between the 25th and 75th
                %percentiles
                percentile25 = prctile(featPV,25);
                percentile75 = prctile(featPV,75);
                feat2use = find(featPV > percentile25 & featPV < percentile75);
                featPos = featPos(feat2use,:);
                featAmp = featAmp(feat2use);
                featBG = featBG(feat2use);
                
            end
            
            %go over the selected features and estimate psfSigma
            numFeats = length(featAmp);
            parameters = zeros(numFeats,5);
            if numFeats >= 1
                
                for iFeat = 1 : numFeats
                    
                    %crop image around selected feature
                    lowerBound = featPos(iFeat,:) - psfSigma5;
                    upperBound = featPos(iFeat,:) + psfSigma5;
                    imageCropped = imageRaw(lowerBound(1):upperBound(1),...
                        lowerBound(2):upperBound(2),1);
                    
                    %estimate sigma if image region contains no NaNs
                    %NaNs appear due to cropping
                    if all(~isnan(imageCropped(:)))
                        
                        %make initial guess for fit (in the order given in fitParameters)
                        initGuess = [psfSigma5+1 psfSigma5+1 featAmp(iFeat) ...
                            psfSigma0 featBG(iFeat)];
                        
                        %fit image and estimate sigma of Gaussian
                        parameters(iFeat,:) = GaussFitND(imageCropped,[],...
                            fitParameters,initGuess);
                        
                    else %otherwise assign NaN
                        
                        parameters(iFeat,:) = NaN;
                        
                    end
                    
                end
                
                %add to array of sigmas
                psfSigma = [psfSigma; parameters(:,4)]; %#ok<AGROW>
                
            end %(if numFeats >= 1)
            
            %display progress
            switch numIter
                case 1
                    progressText(iImage/max(images2use),'Estimating PSF sigma');
                otherwise
                    progressText(iImage/max(images2use),'Repeating PSF sigma estimation');
            end
            
        end %(for iImage = images2use)
        
        %estimate psfSigma as the robust mean of all the sigmas from the fits
        psfSigma = psfSigma(~isnan(psfSigma)); %get rid of NaNs from cropped regions
        numCalcs = length(psfSigma);
        if numCalcs > 0
            
            [psfSigma,sigmaStd,inlierIndx] = robustMean(psfSigma);
            
            %accept new sigma if there are enough observations and inliers
            acceptCalc = (numCalcs >= 100 && length(inlierIndx) >= 0.7*numCalcs) || ...
                (numCalcs >= 50 && length(inlierIndx) >= 0.9*numCalcs) || ...
                (numCalcs >= 10 && length(inlierIndx) == numCalcs);
            
        else
            
            acceptCalc = 0;
            
        end
        
        %show new sigma if estimation is accepted
        if acceptCalc
            disp(sprintf('PSF sigma = %1.3f (%d inliers out of %d observations)',...
                psfSigma,length(inlierIndx),numCalcs));
        else %otherwise alert user that input sigma was retained
            psfSigma = psfSigmaIn;
            disp('Not enough observations to change PSF sigma, using input PSF sigma');
        end
        
    end %(while numIter <= numSigmaIter && acceptCalc && ((psfSigma-psfSigma0)/psfSigma0 > 0.05))
    
    %if maximum number of iterations has been performed but sigma value is not converging
    if numIter == numSigmaIter+1 && acceptCalc && ((psfSigma-psfSigma0)/psfSigma0 > 0.05)
        psfSigma = psfSigmaIn;
        disp('Estimation terminated (no convergence), using input PSF sigma');
    end
    
end %(if numSigmaIter)

%% Mixture-model fitting

%initialize movieInfo
clear movieInfo
movieInfo = repmat(struct('xCoord',[],'yCoord',[],'amp',[]),numImagesRaw,1);

%initialize progress display
progressText(0,'Mixture-model fitting');

%go over all non-empty images ...
for iImage = goodImages
    
    %read raw image
    imageRaw = imread([imageDir filenameBase enumString(imageIndx(iImage),:) '.tif']);
    imageRaw = double(imageRaw) / (2^bitDepth-1);
    
    try %try to detect features in this frame
        
        %fit with mixture-models
        featuresInfo = detectSubResFeatures2D(imageRaw,...
            localMaxima(iImage).cands,psfSigma,testAlpha,visual,doMMF,1,0,mean(bgStdRaw(:)));
        
        %save results
        movieInfo(iImage) = featuresInfo;
        
        %check whether frame is empty
        if isempty(featuresInfo.xCoord)
            emptyFrames = [emptyFrames; iImage]; %#ok<AGROW>
        end
        
    catch %#ok<CTCH> %if detection fails
        
        %label frame as empty
        emptyFrames = [emptyFrames; iImage]; %#ok<AGROW>
        
        %add this frame to the array of frames with failed mixture-model
        %fitting
        framesFailedMMF = [framesFailedMMF; iImage]; %#ok<AGROW>
        
    end
    
    %display progress
    progressText(iImage/numImagesRaw,'Mixture-model fitting');
    
end

%% Post-processing

%sort list of empty frames
emptyFrames = sort(emptyFrames);

%store empty frames and frames where detection failed in structure
%exceptions
exceptions = struct('emptyFrames',emptyFrames,'framesFailedLocMax',...
    framesFailedLocMax,'framesFailedMMF',framesFailedMMF');

%indicate correct frames in movieInfo
tmptmp = movieInfo;
clear movieInfo
movieInfo(firstImageNum:lastImageNum,1) = tmptmp;

%save results
if isstruct(saveResults)
    save([saveResDir filesep saveResFile],'movieParam','detectionParam',...
        'movieInfo','exceptions','localMaxima','background','psfSigma');
end

%go back to original warnings state
warning(warningState);


%% Subfunction 1

function enumString = getStringIndx(digits4Enum)

switch digits4Enum
    case 4
        enumString = repmat('0',9999,4);
        for i = 1 : 9
            enumString(i,:) = ['000' num2str(i)];
        end
        for i = 10 : 99
            enumString(i,:) = ['00' num2str(i)];
        end
        for i = 100 : 999
            enumString(i,:) = ['0' num2str(i)];
        end
        for i = 1000 : 9999
            enumString(i,:) = num2str(i);
        end
    case 3
        enumString = repmat('0',999,3);
        for i = 1 : 9
            enumString(i,:) = ['00' num2str(i)];
        end
        for i = 10 : 99
            enumString(i,:) = ['0' num2str(i)];
        end
        for i = 100 : 999
            enumString(i,:) = num2str(i);
        end
    case 2
        enumString = repmat('0',99,2);
        for i = 1 : 9
            enumString(i,:) = ['0' num2str(i)];
        end
        for i = 10 : 99
            enumString(i,:) = num2str(i);
        end
    case 1
        enumString = repmat('0',9,1);
        for i = 1 : 9
            enumString(i,:) = num2str(i);
        end
end

%% Subfunction 2

%Moved to separate function "spatialMovAveBG"

%% trial stuff

% % %go over all images ...
% % frameMax = repmat(struct('localMaxPosX',[],'localMaxPosY',[],...
% %     'localMaxAmp',[]),numImages,1);
% % for iImage = 1 : numImages
% %
% %     try
% %
% %         %call locmax2d to get local maxima in filtered image
% %         fImg = locmax2d(imageF(:,:,iImage),[1 1]*ceil(3*psfSigma));
% %
% %         %get positions and amplitudes of local maxima
% %         [localMaxPosX,localMaxPosY,localMaxAmp] = find(fImg);
% %         frameMax(iImage).localMaxPosX = localMaxPosX;
% %         frameMax(iImage).localMaxPosY = localMaxPosY;
% %         frameMax(iImage).localMaxAmp = localMaxAmp;
% %
% %     catch
% %
% %         %if command fails, store empty
% %         frameMax(iImage).localMaxPosX = [];
% %         frameMax(iImage).localMaxPosY = [];
% %         frameMax(iImage).localMaxAmp = [];
% %
% %         %add this frame to the array of frames with failed local maxima
% %         %detection and to the array of empty frames
% %         framesFailedLocMax = [framesFailedLocMax; imageIndx(iImage)];
% %         emptyFrames = [emptyFrames; imageIndx(iImage)];
% %
% %     end
% %
% % end
% %
% % %get amplitude cutoff using Otsu's method
% % localMaxAmp = vertcat(frameMax.localMaxAmp);
% % ampCutoff = graythresh(localMaxAmp);
% %
% % %go over all images again ...
% % for iImage = 1 : numImages
% %
% %     %get information about this image's local maxima
% %     localMaxPosX = frameMax(iImage).localMaxPosX;
% %     localMaxPosY = frameMax(iImage).localMaxPosY;
% %     localMaxAmp = frameMax(iImage).localMaxAmp;
% %
% %     if ~isempty(localMaxAmp)
% %
% %         %retain only those maxima with amplitude > cutoff
% %         keepMax = find(localMaxAmp > ampCutoff);
% %         localMaxPosX = localMaxPosX(keepMax);
% %         localMaxPosY = localMaxPosY(keepMax);
% %         localMaxAmp = localMaxAmp(keepMax);
% %         numLocalMax = length(keepMax);
% %
% %         %construct cands structure
% %         if numLocalMax == 0 %if there are no local maxima
% %
% %             %add frames to list of empty frames
% %             cands = [];
% %             emptyFrames = [emptyFrames; imageIndx(iImage)];
% %
% %         else %if there are local maxima
% %
% %             %define background mean and status
% %             cands = repmat(struct('IBkg',bgMean,'status',1,...
% %                 'Lmax',[],'amp',[]),numLocalMax,1);
% %
% %             %store maxima positions and amplitudes
% %             for iMax = 1 : numLocalMax
% %                 cands(iMax).Lmax = [localMaxPosX(iMax) localMaxPosY(iMax)];
% %                 cands(iMax).amp = localMaxAmp(iMax);
% %             end
% %
% %         end
% %
% %         %add the cands of the current image to the rest
% %         localMaxima(iImage).cands = cands;
% %     end
% %
% %     %display progress
% %     progressText(iImage/numImages,'Detecting local maxima');
% %
% % end

% % %allocate memory for background mean and std
% % bgMean = zeros(imageSizeX,imageSizeY,numImages);
% % bgStd = bgMean;
% % bgMeanF = bgMean;
% % bgStdF = bgMean;
% %
% % %initialize progress display
% % progressText(0,'Estimating background');
% %
% % %estimate the background noise mean and standard deviation
% % %use robustMean to get mean and std of intensities
% % %in this method, the intensities of actual features will look like
% % %outliers, so we are effectively getting the mean and std of the background
% % %account for possible spatial heterogeneity by taking a spatial moving
% % %average
% % imageLast5 = image(:,:,end-4:end);
% % [bgMeanLast5,bgStdLast5] = spatialMovAveBG(imageLast5,imageSizeX,imageSizeY);
% %
% % %estimate overall background of first five and last five images
% % imageFirst5 = image(:,:,1:5);
% % [bgMeanAllFirst5,bgStdAllFirst5] = robustMean(imageFirst5(:));
% % [bgMeanAllLast5,bgStdAllLast5] = robustMean(imageLast5(:));
% %
% % %get slope of straight line
% % slopeBgMean = (bgMeanAllFirst5 - bgMeanAllLast5)/(numImages-1);
% % slopeBgStd = (bgStdAllFirst5 - bgStdAllLast5)/(numImages-1);
% %
% % %calculate the background for all images
% % for iImage = 1 : numImages
% %     bgMean(:,:,iImage) = bgMeanLast5 + slopeBgMean * (numImages - iImage);
% %     bgStd(:,:,iImage) = bgStdLast5 + slopeBgStd * (numImages - iImage);
% % end
% %
% % %save results for output
% % mean1 = struct('last5Local',bgMeanLast5,'last5Global',bgMeanAllLast5,...
% %     'first5Global',bgMeanAllFirst5);
% % std1 = struct('last5Local',bgStdLast5,'last5Global',bgStdAllLast5,...
% %     'first5Global',bgStdAllFirst5);
% % raw = struct('mean',mean1,'std',std1);
% %
% % %display progress
% % progressText(0.5,'Estimating background');
% %
% % %do the same for the filtered image
% %
% % %use robustMean to get mean and std of background intensities
% % imageLast5 = imageF(:,:,end-4:end);
% % [bgMeanLast5,bgStdLast5] = spatialMovAveBG(imageLast5,imageSizeX,imageSizeY);
% %
% % %estimate overall background of first five and last five images
% % imageFirst5 = imageF(:,:,1:5);
% % [bgMeanAllFirst5,bgStdAllFirst5] = robustMean(imageFirst5(:));
% % [bgMeanAllLast5,bgStdAllLast5] = robustMean(imageLast5(:));
% %
% % slopeBgMean = (bgMeanAllFirst5 - bgMeanAllLast5)/(numImages-1);
% % slopeBgStd = (bgStdAllFirst5 - bgStdAllLast5)/(numImages-1);
% %
% % %calculate the background for all images
% % for iImage = 1 : numImages
% %     bgMeanF(:,:,iImage) = bgMeanLast5 + slopeBgMean * (numImages - iImage);
% %     bgStdF(:,:,iImage) = bgStdLast5 + slopeBgStd * (numImages - iImage);
% % end
% %
% % %save results for output
% % mean1 = struct('last5Local',bgMeanLast5,'last5Global',bgMeanAllLast5,...
% %     'first5Global',bgMeanAllFirst5);
% % std1 = struct('last5Local',bgStdLast5,'last5Global',bgStdAllLast5,...
% %     'first5Global',bgStdAllFirst5);
% % filtered = struct('mean',mean1,'std',std1);
% %
% % %display progress
% % progressText(1,'Estimating background');
% %
% % %store output
% % background = struct('raw',raw,'filtered',filtered);

% %         bgMeanF1 = bgMeanF(:,:,iImage);
% %         bgMeanMaxF = bgMeanF1(localMax1DIndx);
% %         bgStdF1 = bgStdF(:,:,iImage);
% %         bgStdMaxF = bgStdF1(localMax1DIndx);
% %         bgMean1 = bgMean(:,:,iImage);
% %         bgMeanMax = bgMean1(localMax1DIndx);

