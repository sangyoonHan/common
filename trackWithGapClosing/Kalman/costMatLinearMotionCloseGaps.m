function [costMat,nonlinkMarker,indxMerge,numMerge,indxSplit,numSplit,...
    errFlag] = costMatLinearMotionCloseGaps(trackedFeatInfo,...
    trackedFeatIndx,trackStartTime,trackEndTime,costMatParam,gapCloseParam,...
    kalmanFilterInfo,trackConnect,useLocalDensity,nnDistLinkedFeat,nnWindow)
%COSTMATLINEARMOTIONCLOSEGAPS provides a cost matrix for closing gaps using Kalman filter information (no merging/splitting yet)
%
%SYNOPSIS [costMat,nonlinkMarker,indxMerge,numMerge,indxSplit,numSplit,...
%    errFlag] = costMatLinearMotionCloseGaps(trackedFeatInfo,...
%    trackedFeatIndx,trackStartTime,trackEndTime,costMatParam,gapCloseParam,...
%    kalmanFilterInfo,trackConnect,useLocalDensity,nnDistLinkedFeat,nnWindow)
%
%INPUT  trackedFeatInfo: The positions and amplitudes of the tracked
%                        features from linkFeaturesKalman.
%                        Number of rows = number of tracks.
%                        Number of columns = 8*number of frames.
%                        Each row consists of
%                        [x1 y1 z1 a1 dx1 dy1 dz1 da1 x2 y2 z2 a2 dx2 dy2 dz2 da2 ...]
%                        in image coordinate system (coordinates in
%                        pixels). NaN is used to indicate time points
%                        where the track does not exist.
%       trackedFeatIndx: Connectivity matrix of features between frames.
%                        Rows indicate continuous tracks, while columns
%                        indicate frames. A track that ends before the
%                        last time point is followed by zeros, and a track
%                        that starts at a time after the first time point
%                        is preceded by zeros.
%       trackStartTime : Starting time of all tracks.
%       trackEndTime   : Ending time of all tracks.
%       costMatParam   : Structure containing variables needed for cost
%                        calculation. Contains the fields:
%             .minSearchRadiusCG:Minimum allowed search radius (in pixels).
%             .maxSearchRadiusCG:Maximum allowed search radius (in pixels).
%                               This value is the maximum search radius
%                               between two consecutive frames as when
%                               linking between consecutive frames. It will
%                               be calcualted for different time gaps
%                               based on the scaling factor of Brownian
%                               motion (expanding it will make use of the
%                               field .timeReachConfB).
%             .brownStdMultCG : Factor multiplying Brownian
%                               displacement std to get search radius.
%                               Vector with number of entries equal to
%                               gapCloseParam.timeWindow (defined below).
%             .linStdMultCG   : Factor multiplying linear motion std to get
%                               search radius. Vector with number of entries
%                               equal to gapCloseParam.timeWindow (defined
%                               below).
%             .timeReachConfB : Time gap for reaching confinement for
%                               2D Brownian motion. For smaller time gaps,
%                               expected displacement increases with
%                               sqrt(time gap). For larger time gaps,
%                               expected displacement increases slowly with
%                               (time gap)^0.1.
%             .timeReachConfL : Time gap for reaching confinement for
%                               linear motion. Time scaling similar to
%                               timeReachConfB above.
%             .lenForClassify : Minimum length of a track to classify it as
%                               directed or Brownian.
%             .maxAngle       : Maximum allowed angle between two
%                               directions of motion for potential linking
%                               (in degrees).
%             .closestDistScaleCG:Scaling factor of nearest neighbor
%                                 distance.
%             .maxStdMultCG   : Maximum value of factor multiplying
%                               std to get search radius.
%             .ampRatioLimitCG: Minimum and maximum allowed ratio between
%                               the amplitude of a merged feature and the
%                               sum of the amplitude of the two features
%                               making it.
%       gapCloseParam  : Structure containing variables needed for gap closing.
%                        Contains the fields:
%             .timeWindow : Largest time gap between the end of a track and the
%                           beginning of another that could be connected to it.
%             .tolerance  : Relative change in number of tracks in two
%                           consecutive gap closing steps below which
%                           iteration stops.
%             .mergeSplit : Logical variable with value 1 if the merging
%                           and splitting of trajectories are to be consided;
%                           and 0 if merging and splitting are not allowed.
%       kalmanFilterInfo:Structure array with number of entries equal to
%                        number of frames in movie. Contains the fields:
%             .stateVec   : Kalman filter state vector for each
%                           feature in frame.
%             .stateCov   : Kalman filter state covariance matrix
%                           for each feature in frame.
%             .noiseVar   : Variance of state noise for each
%                           feature in frame.
%             .stateNoise : Estimated state noise for each feature in
%                           frame.
%             .scheme     : 1st column: propagation scheme connecting
%                           feature to previous feature. 2nd column:
%                           propagation scheme connecting feature to
%                           next feature.
%       trackConnect   : Matrix indicating connectivity between tracks (from
%                        initial linking) after gap closing.
%       useLocalDensity: 1 if local density of features is used to expand
%                        their search radius if possible, 0 otherwise.
%       nnDistLinkedFeat:Matrix indicating the nearest neighbor
%                        distances of features linked together within
%                        tracks.
%       nnWindow       : Time window to be used in estimating the
%                        nearest neighbor distance of a track at its start
%                        and end.
%
%OUTPUT costMat       : Cost matrix.
%       nonlinkMarker : Value indicating that a link is not allowed.
%       indxMerge     : Index of tracks that have possibly merged with
%                       tracks that end before the last time points.
%       numMerge      : Number of such tracks.
%       indxSplit     : Index of tracks from which tracks that begin after
%                       the first time point might have split.
%       numSplit      : Number of such tracks.
%       errFlag       : 0 if function executes normally, 1 otherwise.
%
%REMARKS the costs are given by ...
%
%The cost for linking the end of one track to the start of another track is
%given by ...
%
%Khuloud Jaqaman, April 2007

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

costMat = [];
nonlinkMarker = [];
indxMerge = [];
numMerge = [];
indxSplit = [];
numSplit = [];
errFlag = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Input
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%check whether correct number of input arguments was used
if nargin ~= nargin('costMatLinearMotionCloseGaps')
    disp('--costMatLinearMotionCloseGaps: Incorrect number of input arguments!');
    errFlag  = 1;
    return
end

%get cost matrix parameters
minSearchRadius = costMatParam.minSearchRadiusCG;
maxSearchRadius = costMatParam.maxSearchRadiusCG;
brownStdMult = costMatParam.brownStdMultCG;
linStdMult   = costMatParam.linStdMultCG;
timeReachConfB = costMatParam.timeReachConfB;
timeReachConfL = costMatParam.timeReachConfL;
lenForClassify = costMatParam.lenForClassify;
sin2AngleMax = (sin(costMatParam.maxAngle*pi/180))^2;
if useLocalDensity
    closestDistScale = costMatParam.closestDistScaleCG;
    maxStdMult = costMatParam.maxStdMultCG;
else
    closestDistScale = [];
    maxStdMult = [];
end
minAmpRatio = costMatParam.ampRatioLimitCG(1);
maxAmpRatio = costMatParam.ampRatioLimitCG(2);

%get gap closing parameters
timeWindow = gapCloseParam.timeWindow;
mergeSplit = gapCloseParam.mergeSplit;

%find the number of tracks to be linked and the number of frames in the movie
[numTracks,numFrames] = size(trackedFeatInfo);
numFrames = numFrames / 8;

%list the tracks that start and end in each frame
tracksPerFrame = repmat(struct('starts',[],'ends',[]),100,1);
for iFrame = 1 : numFrames    
    tracksPerFrame(iFrame).starts = find(trackStartTime == iFrame); %starts
    tracksPerFrame(iFrame).ends = find(trackEndTime == iFrame); %ends
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Calculate cost matrix
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%get the x,y-coordinates and amplitudes at the starts of tracks
xCoordStart   = zeros(numTracks,1); %x-coordinate
yCoordStart   = zeros(numTracks,1); %y-coordinate
ampStart      = zeros(numTracks,1); %amplitude
for iTrack = 1 : numTracks
    xCoordStart(iTrack) = trackedFeatInfo(iTrack,(trackStartTime(iTrack)-1)*8+1);
    yCoordStart(iTrack) = trackedFeatInfo(iTrack,(trackStartTime(iTrack)-1)*8+2);
    ampStart(iTrack) = trackedFeatInfo(iTrack,(trackStartTime(iTrack)-1)*8+4);
end

%get the x,y-coordinates and amplitudes at the ends of tracks
xCoordEnd   = zeros(numTracks,1);
yCoordEnd   = zeros(numTracks,1);
ampEnd      = zeros(numTracks,1);
for iTrack = 1 : numTracks
    xCoordEnd(iTrack) = trackedFeatInfo(iTrack,(trackEndTime(iTrack)-1)*8+1);
    yCoordEnd(iTrack) = trackedFeatInfo(iTrack,(trackEndTime(iTrack)-1)*8+2);
    ampEnd(iTrack) = trackedFeatInfo(iTrack,(trackEndTime(iTrack)-1)*8+4);
end

%determine the types, velocities and noise stds of all tracks
[trackType,xVel,yVel,noiseStd] = estimTrackTypeParamLM(...
    trackedFeatIndx,trackedFeatInfo,kalmanFilterInfo,trackConnect,...
    lenForClassify);

%find the average noise standard deviation in order to use that for undetermined
%tracks (after removing std = 1 which indicates the simple initialization
%conditions
noiseStdAll = noiseStd(noiseStd ~= 1);
undetBrownStd = prctile(noiseStdAll,95);

%determine the average displacements and search ellipses of all tracks
[dispDrift,dispBrown,longVecSAll,longVecEAll,shortVecSAll,shortVecEAll] = ...
    getAveDispEllipseAll(xVel,yVel,noiseStd,trackType,undetBrownStd,...
    timeWindow,brownStdMult,linStdMult,timeReachConfB,timeReachConfL,...
    minSearchRadius,maxSearchRadius,useLocalDensity,closestDistScale,...
    maxStdMult,nnDistLinkedFeat,nnWindow,trackStartTime,trackEndTime);

%find all pairs of ends and starts that can potentially be linked
%determine this by looking at gaps between ends and starts
%and by looking at the distance between pairs
indxEnd2 = [];
indxStart2 = [];

%find the maximum velocity and multiply that by 2*linStdMult(1)*sqrt(largest
%possible time gap) to get the absolute upper limit of acceptable displacements
maxDispAllowed = max([xVel; yVel]) * 2 * linStdMult(1);

%go over all frames until the one before last
for iFrame = 1 : numFrames - 1

    %find tracks that end in this frame
    endsToConsider = tracksPerFrame(iFrame).ends;
    
    for jFrame = iFrame + 1 : min(iFrame+timeWindow,numFrames)

        %find tracks that start in this frame
        startsToConsider = tracksPerFrame(jFrame).starts;

        %calculate the distance between ends and starts
        dispMat2 = createDistanceMatrix(...
            [xCoordEnd(endsToConsider) yCoordEnd(endsToConsider)],...
            [xCoordStart(startsToConsider) yCoordStart(startsToConsider)]);
        
        %find possible pairs
        [indxEnd3,indxStart3] = find(dispMat2 <= maxDispAllowed * sqrt(jFrame-iFrame));
        if size(indxEnd3,1) == 1
            indxEnd3 = indxEnd3';
            indxStart3 = indxStart3';
        end

        %add them to the list of possible pairs
        indxEnd2 = [indxEnd2; endsToConsider(indxEnd3)];
        indxStart2 = [indxStart2; startsToConsider(indxStart3)];
        
    end %(for jFrame = iFrame + 1 : iFrame + timeWindow)
    
end %(for iFrame = 1 : numFrames)

%get total number of pairs
numPairs = length(indxEnd2);

%clear variables from memory
clear dispMat2 maxDispAllowed

%reserve memory for cost matrix vectors
indx1 = zeros(numPairs,1); %row number in cost matrix
indx2 = zeros(numPairs,1); %column number in cost matrix
cost  = zeros(numPairs,1); %cost value

%go over all possible pairs of starts and ends
for iPair = 1 : numPairs

    %get indices of start and end and the time gap between them
    iStart = indxStart2(iPair);
    iEnd = indxEnd2(iPair);
    
    %determine the time gap between them
    timeGap = trackStartTime(iStart) - trackEndTime(iEnd);

    %get the types of the two tracks
    trackTypeS = trackType(iStart);
    trackTypeE = trackType(iEnd);

    %determine the average displacement and search ellipse of track iStart
    %     dispDriftS = dispDrift(:,timeGap,iStart);
    %     dispBrownS = dispBrown(timeGap,iStart);
    longVecS = longVecSAll(:,timeGap,iStart);
    shortVecS = shortVecSAll(:,timeGap,iStart);

    %determine the average displacement and search ellipse of track iEnd
    %     dispDriftE = dispDrift(:,timeGap,iEnd);
    %     dispBrownE = dispBrown(timeGap,iEnd);
    longVecE = longVecEAll(:,timeGap,iEnd);
    shortVecE = shortVecEAll(:,timeGap,iEnd);

    %calculate the vector connecting the end of track iEnd to the
    %start of track iStart
    dispVec = [xCoordEnd(iEnd) - xCoordStart(iStart) ...
        yCoordEnd(iEnd) - yCoordStart(iStart)];

    %calculate the magnitudes of the long and short search vectors
    %of both end and start
    longVecMagE = sqrt(longVecE' * longVecE);
    shortVecMagE = sqrt(shortVecE' * shortVecE);
    longVecMagS = sqrt(longVecS' * longVecS);
    shortVecMagS = sqrt(shortVecS' * shortVecS);

    %project the connecting vector onto the long and short vectors
    %of track iEnd and take absolute value
    projEndLong = abs(dispVec * longVecE) / longVecMagE;
    projEndShort = abs(dispVec * shortVecE) / shortVecMagE;

    %project the connecting vector onto the long and short vectors
    %of track iStart and take absolute value
    projStartLong = abs(dispVec * longVecS) / longVecMagS;
    projStartShort = abs(dispVec * shortVecS) / shortVecMagS;

    %get the absolute value of dispVec
    dispVec = abs(dispVec);

    %decide whether this is a possible link based on the types of
    %the two tracks
    switch trackTypeE
        case 1 %if end is directed
            switch trackTypeS
                case 1 %if start is directed

                    %calculate the square sine of the angle between velocity vectors
                    sin2Angle = 1 -  (longVecE' * longVecS / (longVecMagE * longVecMagS))^2;

                    %check whether the end of track iEnd is within the search
                    %region of the start of track iStart and vice versa
                    %and whether the angle between the two
                    %directions of motion is within acceptable
                    %bounds
                    possibleLink = projEndLong <= longVecMagE && ...
                        projEndShort <= shortVecMagE && ...
                        projStartLong <= longVecMagS && ...
                        projStartShort <= shortVecMagS && ...
                        sin2Angle <= sin2AngleMax;

                otherwise %if start is Brownian or undetermined

                    %check whether the start of track iStart is within the search
                    %region of the end of track iEnd
                    possibleLink = projEndLong <= longVecMagE && ...
                        projEndShort <= shortVecMagE;

            end
        case 0 %if end is Brownian
            switch trackTypeS
                case 1 %if start is directed

                    %check whether the end of track iEnd is within the search
                    %region of the start of track iStart
                    possibleLink = projStartLong <= longVecMagS && ...
                        projStartShort <= shortVecMagS;

                case 0 %if start is Brownian

                    %check whether the end of track iEnd is within the search
                    %region of the start of track iStart and vice versa
                    possibleLink = projEndLong <= longVecMagE && ...
                        projEndShort <= shortVecMagE && ...
                        projStartLong <= longVecMagS && ...
                        projStartShort <= shortVecMagS;

                otherwise %if start is undetermined

                    %check whether the end of track iEnd is within the search
                    %region of the start of track iStart and vice versa
                    possibleLink = projEndLong <= longVecMagE && ...
                        projEndShort <= shortVecMagE;

            end
        otherwise %if end is undetermined

            %check whether the end of track iEnd is within the search
            %region of the start of track iStart
            possibleLink = projStartLong <= longVecMagS && ...
                projStartShort <= shortVecMagS;

    end

    %if this is a possible link ...
    if possibleLink

        %specify the location of this pair in the cost matrix
        indx1(iPair) = iEnd; %row number
        indx2(iPair) = iStart; %column number

        %         %calculate the cost of linking them (type 1)
        %         cost12 = (dispVec(1) / (dispDriftE(1) + dispBrownE))^2 + ... %compare x-displacement to average x-displacement of end
        %             (dispVec(1) / (dispDriftS(1) + dispBrownS))^2 + ... %compare x-displacement to average x-displacement of start
        %             (dispVec(2) / (dispDriftE(2) + dispBrownE))^2 + ... %compare y-displacement to average y-displacement of end
        %             (dispVec(2) / (dispDriftS(2) + dispBrownS))^2; %compare y-displacement to average y-displacement of start

        %                 %calculate the cost of linking them  (type 2)
        %                 cost12 = dispVec' * dispVec;

        %calculate the cost of linking them (type 3)
        dispVecMag2 = dispVec * dispVec';
        if trackTypeE == 1 && trackTypeS == 1
            cost12 = dispVecMag2 * sin2Angle;
        else
            cost12 = dispVecMag2;
        end

        %add this cost to the list of costs
        cost(iPair) = cost12;

    end %(if possibleLink)

end %(for iPair = 1 : numPairs)

%keep only pairs that turned out to be possible
possiblePairs = find(indx1 ~= 0);
indx1 = indx1(possiblePairs);
indx2 = indx2(possiblePairs);
cost  = cost(possiblePairs);
clear possiblePairs

%remove possible links with extremely high costs that can be considered
%outliers

%calculate mean of costs
meanCost = mean(cost);

%calculate standard deviation of costs
stdCost = std(cost);

%find indices of links with costs closer than 3*std from the mean
indxInlier = find(cost < meanCost + 3 * stdCost);

%retain only those links
indx1 = indx1(indxInlier);
indx2 = indx2(indxInlier);
cost  = cost(indxInlier);

%clear memory
clear meanCost stdCost indxInlier

%define some merging and splitting variables
numMerge  =  0; %index counting merging events
indxMerge = []; %vector storing merging track number
altCostMerge = []; %vector storing alternative costs of not merging
numSplit  =  0; %index counting splitting events
indxSplit = []; %vector storing splitting track number
altCostSplit = []; %vector storing alternative costs of not splitting

%if merging and splitting are to be considered ...
if mergeSplit

    %find the maximum velocity and multiply that by 2*linStdMult(1)
    %to get the absolute upper limit of acceptable displacement between two
    %frames
    maxDispAllowed = max([xVel; yVel]) * 2 * linStdMult(1);

    %costs of merging

    %go over all track end times
    for endTime = 1 : numFrames-1

        %find tracks that end in this frame
        endsToConsider = tracksPerFrame(endTime).ends;
        
        %find tracks that start before or in this frame and end after this
        %frame
        mergesToConsider = intersect(vertcat(tracksPerFrame(1:endTime).starts),...
            vertcat(tracksPerFrame(endTime+1:end).ends));

        %get index indicating frame of merging
        timeIndx  = endTime*8;

        %calculate displacement between track ends and other tracks in the
        %next frame
        dispMat2 = createDistanceMatrix([xCoordEnd(endsToConsider) ...
            yCoordEnd(endsToConsider)],[trackedFeatInfo(mergesToConsider, ...
            timeIndx+1) trackedFeatInfo(mergesToConsider,timeIndx+2)]);

        %find possible pairs
        [indxEnd2,indxMerge2] = find(dispMat2 <= maxDispAllowed);
        numPairs = length(indxEnd2);
        
        %clear memory
        clear dispMat2
        
        %map from indices to track indices
        indxEnd2 = endsToConsider(indxEnd2);
        indxMerge2 = mergesToConsider(indxMerge2);

        %reserve memory for cost vectors and related vectors
        indx1MS   = zeros(numPairs,1);
        indx2MS   = zeros(numPairs,1);
        costMS    = zeros(numPairs,1);
        altCostMS = zeros(numPairs,1);
        indxMSMS  = zeros(numPairs,1);
        
        %go over all possible pairs
        for iPair = 1 : numPairs

            %get indices of ending track and track it might merge with
            iEnd = indxEnd2(iPair);
            iMerge = indxMerge2(iPair);

            %determine the search ellipse of track iEnd
            longVecE = longVecEAll(:,1,iEnd);
            shortVecE = shortVecEAll(:,1,iEnd);

            %calculate the magnitudes of the long and short search vectors
            %of the end
            longVecMagE = sqrt(longVecE' * longVecE);
            shortVecMagE = sqrt(shortVecE' * shortVecE);

            %calculate the vector connecting the end of track iEnd to the
            %point of merging
            dispVec = [xCoordEnd(iEnd) - trackedFeatInfo(iMerge,timeIndx+1) ...
                yCoordEnd(iEnd) - trackedFeatInfo(iMerge,timeIndx+2)];

            %project the connecting vector onto the long and short vectors
            %of track iEnd and take absolute value
            projEndLong = abs(dispVec * longVecE) / longVecMagE;
            projEndShort = abs(dispVec * shortVecE) / shortVecMagE;

            %get the absolute value of dispVec
            dispVec = abs(dispVec);

            %get the amplitude at the end of track iEnd
            ampE = ampEnd(iEnd);
            
            %get the amplitude of the merging track at the point of merging
            %and the point before it
            ampM = trackedFeatInfo(iMerge,8*endTime+4); %at point of merging
            ampM1 = trackedFeatInfo(iMerge,8*(endTime-1)+4); %just before merging
            
            %calculate the ratio of the amplitude after merging to the sum
            %of the amplitudes before merging
            ampRatio = ampM / (ampE + ampM1);
            
            %decide whether this is a possible link based on displacement
            %and amplitude ratio
            %check whether the merging feature is within the search region 
            %of the end of track iEnd and that the amplitude ratio is
            %within acceptable limits
            possibleLink = projEndLong <= longVecMagE && ...
                projEndShort <= shortVecMagE && ...
                ampRatio >= minAmpRatio && ampRatio <= maxAmpRatio;
            
            %if this is a possible link ...
            if possibleLink

                %calculate the cost of linking
                dispVecMag2 = dispVec * dispVec'; %due to displacement
                ampCost = ampRatio; %due to amplitude
                ampCost(ampCost<1) = ampCost(ampCost<1) ^ (-2); %punishment harsher when intensity of merged feature < sum of intensities of merging features
                cost12 = dispVecMag2 * ampCost; %cost

                %add this cost to the list of costs
                costMS(iPair) = cost12;

                %check whether the track being merged with has had
                %something possibly merging with it in this same frame
                prevAppearance = find(indxMSMS == iMerge);

                %if this track in this frame did not appear before ...
                if isempty(prevAppearance)

                    %increase the "merge index" by one
                    numMerge = numMerge + 1;

                    %save the merging track's index
                    indxMSMS(iPair) = iMerge;

                    %store the location of this pair in the cost matrix
                    indx1MS(iPair) = iEnd; %row number
                    indx2MS(iPair) = numMerge+numTracks; %column number

                    %calculate the alternative cost of not merging for the
                    %track that the end is possibly merging with
                    %this primarily depends on intensities
                    ampCost = ampM / ampM1;
                    ampCost(ampCost<1) = ampCost(ampCost<1) ^ (-2); %cost of "merged" feature merging with nothing
                    cost12 = dispVecMag2 * ampCost; %alternative cost

                    %add this cost to the list of alternative costs
                    altCostMS(iPair) = cost12;

                else %if this track in this frame appeared before
                    
                    %do not increase the "merge index" or save the merging
                    %track's index (they are already saved)
                    
                    %store the location of this pair in the cost matrix
                    indx1MS(iPair) = iEnd; %row number
                    indx2MS(iPair) = indx2MS(prevAppearance); %column number
                    
                    %no need to calculate and save the alternative cost
                    %since that is already saved from previous appearance
                    
                end %(if isempty(prevAppearance))
                
            end %(if possibleLink)

        end %(for iPair = 1 : numPairs)

        %keep only pairs that turned out to be possible
        possiblePairs = find(indx1MS ~= 0);
        indx1MS   = indx1MS(possiblePairs);
        indx2MS   = indx2MS(possiblePairs);
        costMS    = costMS(possiblePairs);
        possibleMerges = find(indxMSMS ~= 0);
        indxMSMS  = indxMSMS(possibleMerges);
        altCostMS = altCostMS(possibleMerges);
        clear possiblePairs possibleMerges
        
        %append these vectors to overall cost and related vectors
        indx1 = [indx1; indx1MS];
        indx2 = [indx2; indx2MS];
        cost  = [cost; costMS];
        altCostMerge = [altCostMerge; altCostMS];
        indxMerge = [indxMerge; indxMSMS];

    end %(for endTime = 1 : numFrames-1)

    %costs of splitting

    %go over all track starting times
    for startTime = 2 : numFrames

        %find tracks that start in this frame
        startsToConsider = tracksPerFrame(startTime).starts;
        
        %find tracks that start before this frame and end after or in this frame
        splitsToConsider = intersect(vertcat(tracksPerFrame(1:startTime-1).starts),...
            vertcat(tracksPerFrame(startTime:end).ends));

        %get index indicating time of splitting
        timeIndx  = (startTime-2)*8;

        %calculate displacement between track starts and other tracks in the
        %previous frame
        dispMat2 = createDistanceMatrix([xCoordStart(startsToConsider) ...
            yCoordStart(startsToConsider)],[trackedFeatInfo(splitsToConsider, ...
            timeIndx+1) trackedFeatInfo(splitsToConsider,timeIndx+2)]);

        %find possible pairs
        [indxStart2,indxSplit2] = find(dispMat2 <= maxDispAllowed);
        numPairs = length(indxStart2);
        
        %clear memory
        clear dispMat2

        %map from indices to track indices
        indxStart2 = startsToConsider(indxStart2);
        indxSplit2 = splitsToConsider(indxSplit2);

        %reserve memory for cost vectors and related vectors
        indx1MS   = zeros(numPairs,1);
        indx2MS   = zeros(numPairs,1);
        costMS    = zeros(numPairs,1);
        altCostMS = zeros(numPairs,1);
        indxMSMS  = zeros(numPairs,1);
        
        %go over all possible pairs
        for iPair = 1 : numPairs

            %get indices of starting track and track it might have split from
            iStart = indxStart2(iPair);
            iSplit = indxSplit2(iPair);

            %determine the search ellipse of track iStart
            longVecS = longVecSAll(:,1,iStart);
            shortVecS = shortVecSAll(:,1,iStart);

            %calculate the magnitudes of the long and short search vectors
            %of the start
            longVecMagS = sqrt(longVecS' * longVecS);
            shortVecMagS = sqrt(shortVecS' * shortVecS);

            %calculate the vector connecting the end of track iStart to the
            %point of splitting
            dispVec = [xCoordStart(iStart) - trackedFeatInfo(iSplit,timeIndx+1) ...
                yCoordStart(iStart) - trackedFeatInfo(iSplit,timeIndx+2)];

            %project the connecting vector onto the long and short vectors
            %of track iStart and take absolute value
            projStartLong = abs(dispVec * longVecS) / longVecMagS;
            projStartShort = abs(dispVec * shortVecS) / shortVecMagS;

            %get the absolute value of dispVec
            dispVec = abs(dispVec);

            %get the amplitude at the start of track iStart
            ampS = ampStart(iStart);
            
            %get the amplitude of the splitting track at the point of splitting
            %and the point before it
            ampSp1 = trackedFeatInfo(iSplit,8*(startTime-1)+4); %at point of splitting
            ampSp = trackedFeatInfo(iSplit,8*(startTime-2)+4); %just before splitting
            
            %calculate the ratio of the amplitude before splitting to the sum
            %of the amplitudes after splitting
            ampRatio = ampSp / (ampS + ampSp1);
            
            %decide whether this is a possible link based on displacement
            %check whether the splitting feature is within the search region 
            %of the start of track iStart
            possibleLink = projStartLong <= longVecMagS && ...
                projStartShort <= shortVecMagS && ...
                ampRatio >= minAmpRatio && ampRatio <= maxAmpRatio;

            %if this is a possible link ...
            if possibleLink

                %calculate the cost of linking
                dispVecMag2 = dispVec * dispVec';
                ampCost = ampRatio; %due to amplitude
                ampCost(ampCost<1) = ampCost(ampCost<1) ^ (-2); %punishment harsher when intensity of splitting feature < sum of intensities of features after splitting
                cost12 = dispVecMag2 * ampCost;

                %add this cost to the list of costs
                costMS(iPair) = cost12;

                %check whether the track being split from has had something
                %possibly splitting from it in this same frame
                prevAppearance = find(indxMSMS == iSplit);

                %if this track in this frame did not appear before ...
                if isempty(prevAppearance)

                    %increase the "split index" by one
                    numSplit = numSplit + 1;

                    %save the merging track's number
                    indxMSMS(iPair) = iSplit;

                    %store the location of this pair in the cost matrix
                    indx1MS(iPair) = numSplit+numTracks; %row number
                    indx2MS(iPair) = iStart; %column number

                    %calculate the alternative cost of not splitting for the
                    %track that the start is possibly splitting from
                    %this primarily depends on intensities
                    ampCost = ampSp / ampSp;
                    ampCost(ampCost<1) = ampCost(ampCost<1) ^ (-2); %cost of "splitting" feature having "nothing" split from it
                    cost12 = dispVecMag2 * ampCost; %alternative cost

                    %add this cost to the list of alternative costs
                    altCostMS(iPair) = cost12;
                    
                else %if this track in this frame appeared before
                    
                    %do not increase the "split index" or save the
                    %splitting track's index (they are already saved)
                    
                    %store the location of this pair in the cost matrix
                    indx1MS(iPair) = indx1MS(prevAppearance); %row number
                    indx2MS(iPair) = iStart; %column number
                    
                    %no need to calculate and save the alternative cost
                    %since that is already saved from previous appearance
                    
                end %(if isempty(prevAppearance))

            end %(if possibleLink)

        end %(for for iPair = 1 : numPairs)

        %keep only pairs that turned out to be possible
        possiblePairs = find(indx1MS ~= 0);
        indx1MS   = indx1MS(possiblePairs);
        indx2MS   = indx2MS(possiblePairs);
        costMS    = costMS(possiblePairs);
        possibleSplits = find(indxMSMS ~= 0);
        altCostMS = altCostMS(possibleSplits);
        indxMSMS  = indxMSMS(possibleSplits);
        clear possiblePairs possibleSplits
        
        %append these vectors to overall cost and related vectors
        indx1 = [indx1; indx1MS];
        indx2 = [indx2; indx2MS];
        cost  = [cost; costMS];
        altCostSplit = [altCostSplit; altCostMS];
        indxSplit = [indxSplit; indxMSMS];

    end %(for startTime = 2 : numFrames)

end %(if mergeSplit)

%create cost matrix without births and deaths
numEndSplit = numTracks + numSplit;
numStartMerge = numTracks + numMerge;
costMat = sparse(indx1,indx2,cost,numEndSplit,numStartMerge);

%append cost matrix to allow births and deaths ...

%determine the cost of birth and death
costBD = max(max(max(costMat))+1,1);

%get the cost for the lower right block
costLR = min(min(min(costMat))-1,-1);

%create cost matrix that allows for births and deaths
costMat = [costMat ... %costs for links (gap closing + merge/split)
    spdiags([costBD*ones(numTracks,1); altCostSplit],0,numEndSplit,numEndSplit); ... %costs for death
    spdiags([costBD*ones(numTracks,1); altCostMerge],0,numStartMerge,numStartMerge) ...  %costs for birth
    sparse(indx2,indx1,costLR*ones(length(indx1),1),numStartMerge,numEndSplit)]; %dummy costs to complete the cost matrix

%determine the nonlinkMarker
nonlinkMarker = min(floor(full(min(min(costMat))))-5,-5);


%%%%% ~~ the end ~~ %%%%%




% %             %get the types of the two tracks
% %             trackTypeE = trackType(iEnd);
% %             trackTypeM = trackType(iMerge);

% % %get the direction of motion of the merging track
% % %longVecM will be already normalized to unity
% % longVecM = longVecEAll(:,1,iMerge);
% % longVecM = longVecM / sqrt(longVecM' * longVecM);



% %             %decide whether this is a possible link based on the types of
% %             %the two tracks
% %             switch trackTypeE
% %                 case 1 %if end is directed
% %                     switch trackTypeM
% %                         case 1 %if merging track is directed
% % 
% %                             %calculate the square sine of the angle between velocity vectors
% %                             sin2Angle = 1 - (longVecE' * longVecM / longVecMagE)^2;
% % 
% %                             %check whether the merging feature is within
% %                             %the search region of the end of track iEnd
% %                             %and whether the angle between the two
% %                             %directions of motion is within acceptable
% %                             %bounds
% %                             possibleLink = projEndLong <= longVecMagE && ...
% %                                 projEndShort <= shortVecMagE && ...
% %                                 sin2Angle <= sin2AngleMax;
% % 
% %                         otherwise %if merging track is Brownian or undetermined
% % 
% %                             %check whether the merging feature is within
% %                             %the search region of the end of track iEnd
% %                             possibleLink = projEndLong <= longVecMagE && ...
% %                                 projEndShort <= shortVecMagE;
% % 
% %                     end
% %                 otherwise %if end is Brownian or undetermined
% % 
% %                     %check whether the merging feature is within
% %                     %the search region of the end of track iEnd
% %                     possibleLink = projEndLong <= longVecMagE && ...
% %                         projEndShort <= shortVecMagE;
% % 
% %             end


% %                 if trackTypeE == 1 && trackTypeM == 1
% %                     cost12 = dispVecMag2 * sin2Angle;
% %                 else
% %                     cost12 = dispVecMag2;
% %                 end



% %             %get the types of the two tracks
% %             trackTypeS = trackType(iStart);
% %             trackTypeSp = trackType(iSplit);

% %             %get the direction of motion of the splitting track
% %             %longVecSp will be already normalized to unity
% %             longVecSp = longVecEAll(:,1,iSplit);
% %             longVecSp = longVecSp / sqrt(longVecSp' * longVecSp);




% %             %decide whether this is a possible link based on the types of
% %             %the two tracks
% %             switch trackTypeS
% %                 case 1 %if start is directed
% %                     switch trackTypeSp
% %                         case 1 %if splitting track is directed
% % 
% %                             %calculate the square sine of the angle between velocity vectors
% %                             sin2Angle = 1 - (longVecS' * longVecSp / longVecMagS)^2;
% % 
% %                             %check whether the splitting feature is within
% %                             %the search region of the start of track iStart
% %                             %and whether the angle between the two
% %                             %directions of motion is within acceptable
% %                             %bounds
% %                             possibleLink = projStartLong <= longVecMagS && ...
% %                                 projStartShort <= shortVecMagS && ...
% %                                 sin2Angle <= sin2AngleMax;
% % 
% %                         otherwise %if splitting track is Brownian or undetermined
% % 
% %                             %check whether the splitting feature is within
% %                             %the search region of the start of track iStart
% %                             possibleLink = projStartLong <= longVecMagS && ...
% %                                 projStartShort <= shortVecMagS;
% % 
% %                     end
% %                 otherwise %if start is Brownian or undetermined
% % 
% %                     %check whether the splitting feature is within the
% %                     %search region of the start of track iStart
% %                     possibleLink = projStartLong <= longVecMagS && ...
% %                         projStartShort <= shortVecMagS;
% % 
% %             end

% %                 if trackTypeS == 1 && trackTypeSp == 1
% %                     cost12 = dispVecMag2 * sin2Angle;
% %                 else
% %                     cost12 = dispVecMag2;
% %                 end

