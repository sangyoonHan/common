function seqM = getSeqOfEventsMatrix(obj)
%getSeqOfEventsMatrix returns an aggregate seqOfEvents matrix combining all of the tracks
% 
% The third and forth columns are shifted to represent the segments in the segments matrix
% The fifth column represents the original compound track index number
%
% See also Tracks

%    seqM = cellfun( ...
%        @(s,iSeg,iTrack) [s iSeg(ones(size(s,1),1)) iTrack(ones(size(s,1),1)) ], ...
%        {obj.seqOfEvents}, ...
%        num2cell( ...
%            [0 ...
%                cumsum( ...
%                    cellfun('size',{obj(1:end-1).tracksFeatIndxCG},1) ...
%                ) ...
%            ] ...
%        ), ...
%        num2cell( 1:length(obj) ), ...
%        'UniformOutput',false);
    seqC = {obj.seqOfEvents};
    seqM = vertcat(seqC{:});
    seqI = [0 cumsum(cellfun('size',seqC(1:end-1),1))]+1;

    seqM(seqI,5) = [0 obj(1:end-1).numSegments]';
    seqM(:,5) = cumsum(seqM(:,5));

    seqM(seqI,6) = 1;
    seqM(:,6) = cumsum(seqM(:,6));
    
    seqM(:,3) = seqM(:,3) + seqM(:,5);
    seqM(:,4) = seqM(:,4) + seqM(:,5);
    seqM = seqM(:,[1:4 6]);
end
