function testKDTreeClosestPoint
% This function test the KDTreeClosestPoint.
%
% See KDTreeClosestPoint.m for details.
%
% Sebastien Besson, Oct 2011

% Generate random input and query points
dim=2;
nInPts= 1000000;
nQueryPts =100;
X = rand(nInPts,dim);
C = rand(nQueryPts,dim);

% Using KDTreeClosestPoint
fprintf('Running KDTreeClosestPoint for %d input points and %d query points of dimension %d\n',...
    nInPts,nQueryPts,dim);
tic
[idx,d] = KDTreeClosestPoint(X,C);
toc

% Using createDistanceMatrix
disp('Creating full distance matrix');
tic
D = createDistanceMatrix(X,C);
[d2,idx2] = min(D);
toc

assert(all(idx(:)==idx2(:)));
assert(all(d(:)==d2(:)))
