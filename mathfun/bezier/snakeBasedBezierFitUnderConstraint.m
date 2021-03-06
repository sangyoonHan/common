function [C,T,res,lambda] = snakeBasedBezierFitUnderConstraint(data,n,beta,maxDist,varargin)
% snakeBasedBezierFit computes the optimal n^th Bezier curves that fits
% the data points using a constrainted snake-based functional.
%
% Required Inputs:
% data           A m x d array representing a set of d-dimensional points
% n              Degree of the Bezier curve.
% beta           Regularization weight parameter.
% maxDist        Maximum distance between first data point and extremities
%
% Optional Inputs:
% MaxFunEvals    Maximum number of fonctional evaluations during lsqnonlin.
% MaxIter        Maximum number of interations during lsqnonlin.
% Display        Verbose mode during lsqnonlin.
% TolX           Tolerance on the solution (i.e. t) during lsqnonlin.
% TolFun         Tolerance on the functional during lsqnonlin.
%
% Outputs:
%
% C:         Control points of the optimal Bezier curve. a (n+1)xd matrix
% T:         a mx1 vector
% res:       a mx1 residual vector
% lambda     a structure lambda whose fields contain the Lagrange
%            multipliers at the solution [C;T]
%
% Sylvain Berlemont, Nov. 2011

%% Parse inputs
ip = inputParser;
ip.CaseSensitive = false;
ip.addRequired('data', @isnumeric);
ip.addRequired('n', @(n) n > 0);
ip.addRequired('beta', @(beta) beta >= 0);
ip.addRequired('maxDist', @(maxDist) maxDist >= 0);
ip.addParamValue('MaxFunEvals', 1e4, @isscalar);
ip.addParamValue('MaxIter', 1e4, @isscalar);
ip.addParamValue('Display', 'off', @isstr);
ip.addParamValue('TolX', 1e-8, @isscalar);
ip.addParamValue('TolFun', 1e-8, @isscalar);

ip.parse(data, n, beta, maxDist, varargin{:});
maxFunEvals = ip.Results.MaxFunEvals;
maxIter = ip.Results.MaxIter;
display = ip.Results.Display;
tolX = ip.Results.TolX;
tolFun = ip.Results.TolFun;

%% Setup the optimization algorithm
opts = optimset('Algorithm', 'interior-point', ...
  'DerivativeCheck', 'off', ...
  'Display', display, ...
  'FunValCheck', 'off', ...
  'GradObj', 'on', ...
  'GradConstr', 'on', ...
  'Hessian', 'off', ...
  'HessFcn', @hessianfcn, ...
  'MaxFunEvals', maxFunEvals, ...
  'MaxIter', maxIter, ...
  'TolX', tolX, ...
  'Tolfun', tolFun);

% Array of function handlers for regularization term computation
regFuncs = {@computeRegTermN1D2, @computeRegTermN2D2, @computeRegTermN3D2;...
  @computeRegTermN1D3, @computeRegTermN2D3, @computeRegTermN3D3};

%% Compute an initial solution
[m d] = size(data);
% dimension of the problem is equal to
% - number of control point coordinates: d * (n+1)
% - number of nodes without the first and last ones: m-2
pDim = d * (n+1) + (m-2);

% Compute the initial nodes
T = linspace(0,1,m)';
% Compute the initial control points
Cnk = diag([1 cumprod(n:-1:1) ./ cumprod(1:n)]);
Cn_1k = diag([1 cumprod(n-1:-1:1) ./ cumprod(1:n-1)]);
Cn_2k = diag([1 cumprod(n-2:-1:1) ./ cumprod(1:n-2)]);

B = (bsxfun(@power, T, 0:n) .* bsxfun(@power, 1 - T, n:-1:0)) * Cnk;
[Q1 R11] = qr(B,0);
C = R11 \ (Q1' * data);
% Note we do not optimize t1 and tm since t1=0 and tm=1 in all cases.
X = [C(:);T(2:end-1)];

% Constraints for T value in [0,1]
lb = -inf(size(X));
ub = +inf(size(X));
lb(d * (n+1) + 1:end) = 0;
ub(d * (n+1) + 1:end) = 1;

maxDist2 = maxDist^2;

%% Pre-compute various constants
j = (0:n-1)';
k = 1:n-1;
fact_j = arrayfun(@factorial, j);                        % j!
fact_n_1 = factorial(n - 1);                             % (n-1)!
fact_2n_1 = factorial(2 * n - 1);                        % (2n-1)!
fact_2n_j_2 = arrayfun(@factorial, 2 * n - j - 2);       % (2 * n - j - 2)!
fact_n_j_1 = arrayfun(@factorial, n + j - 1);            % (n + j - 1)!
binom_n_1_j = arrayfun(@(j) nchoosek(n-1,j), j);
binom_n_1_k = arrayfun(@(k) nchoosek(n-1,k), k);
binom_n_1_k_1 = arrayfun(@(k) nchoosek(n-1,k-1), k);

C1 = binom_n_1_j .* fact_j .* fact_2n_j_2 / fact_2n_1;

C2 = fact_n_j_1 ./ fact_j * factorial(n-1) / fact_2n_1;

C3 = bsxfun(@times, binom_n_1_j, bsxfun(@times, 2 * n - ...
  bsxfun(@plus, j, k) - 1, binom_n_1_k_1) - bsxfun(@times, ...
  bsxfun(@plus, j, k), binom_n_1_k)) .* factorial(bsxfun(@plus, j, k) - 1) ...
  .* factorial(2 * n - bsxfun(@plus,j,k) - 2) / fact_2n_1;

k = 1:n-1;
l = k';
fact_k = arrayfun(@factorial, k);                        % k!
fact_k_1 = arrayfun(@factorial, k - 1);                  % (k-1)!
fact_2n_k_1 = arrayfun(@factorial, 2 * n - k - 1);       % (2 * n - k - 1)!
fact_2n_k_2 = arrayfun(@factorial, 2 * n - k - 2);       % (2 * n - k - 2)!
fact_n_k_2 = arrayfun(@factorial, n + k - 2);            % (n + k - 2)!
binom_n_k = arrayfun(@(k) nchoosek(n,k), k);
binom_n_1_k = arrayfun(@(k) nchoosek(n-1,k), k);
binom_n_1_k_1 = arrayfun(@(k) nchoosek(n-1,k-1), k);

C4 = (binom_n_1_k_1 .* fact_k_1 .* fact_2n_k_1 - binom_n_1_k .* fact_k .* ...
  fact_2n_k_2) / fact_2n_1;
C5 = fact_n_1 * fact_n_k_2 ./ (fact_k_1 * fact_2n_1) .* (1 - (n+k-1) ./ k);
C6 = (bsxfun(@times, bsxfun(@plus, k, l - 1), binom_n_1_k) .* bsxfun(@plus, ...
  (1 - 2 * n) * binom_n_1_k_1', bsxfun(@times, bsxfun(@plus,k,l), binom_n_k')) ...
  + bsxfun(@times, bsxfun(@plus, k, l + 1 - 2 * n), binom_n_1_k_1) .* ...
  bsxfun(@plus, - 2 * n * binom_n_1_k_1' - binom_n_1_k', bsxfun(@times, ...
  bsxfun(@plus, k, l), binom_n_k'))) .* factorial(bsxfun(@plus, k, l - 2)) ...
  .* factorial(bsxfun(@plus, 2 * n - k, -l - 2)) / fact_2n_1;

%% Optimization
[X,~,~,~,lambda] = fmincon(@fun,X,[],[],[],[],lb,ub,@fcon,opts);

% Compute the residual
T = [0; X(d * (n + 1) + 1:end); 1];
B = (bsxfun(@power, T, 0:n) .* bsxfun(@power, 1 - T, n:-1:0)) * Cnk;
res = sqrt(sum((B * C - data).^2,2));

  function [F, G] = fun(X)
    
    % Retrieve the control point coordinates from X
    C = reshape(X(1:d * (n + 1)), n + 1, d);
    
    % Retrieve the nodes from X and add t0 and tm
    T = [0; X(d * (n + 1) + 1:end); 1];
    
    % Compute the Bernstein matrix
    B = (bsxfun(@power, T, 0:n) .* bsxfun(@power, 1 - T, n:-1:0)) * Cnk;
    
    % Compute the data fidelity term
    dataFidelity = sum(sum((data - B * C).^2, 2));
    
    % Append the regularization term and the contraints
    F = dataFidelity + beta * regFuncs{d-1,n}(C);
    
    if nargout > 1
      % Compute the Bernstein matrix of order n-1
      Bn_1 = (bsxfun(@power, T, 0:n-1) .* bsxfun(@power, 1 - T, n-1:-1:0)) * Cn_1k;
    
      % Compute the first term of dF/dxk. dFdC is a (n+1) x d matrix where
      % dFdC(k,l) = 1st term of the derivative of F with respect to the lth
      % coordinate of the kth control point.
      dFdC1 = 2 * B' * (B * C - data);
      
      % Compute the second term of dF/dxk with k = 0. dFdC2_k0 is a 1 x d
      % vector where dFdC2_k0(l) = 2nd term of the derivative of F with
      % respect to the lth coordinate of the first control point (k=0).
      dFdC2_k0 = -2 * beta * n^2 * sum(bsxfun(@times, diff(C,1,1), C1), 1);
      
      % Compute the second term of dF/dxk with k = n. dFdC2_kn is a 1 x d
      % vector where dFdC2_kn(l) = 2nd term of the derivative of F with
      % respect to the lth coordinate of the last control point (k=n).
      dFdC2_kn = 2 * beta * n^2 * sum(bsxfun(@times, diff(C,1,1), C2), 1);
      
      % Compute the second term of dF/dxk with 0 < k < n. dFdC2_k is (n-1)
      % x d matrix where dFdC2_k(k,l) = 2nd term of the derivative of F
      % with respect to the lth coordinate of the kth point.
      dFdC2_k = 2 * beta * n^2 * permute(sum(bsxfun(@times, permute(C3, ...
        [1 3 2]), diff(C,1,1)), 1), [3 2 1]);
      
      G = zeros(pDim, 1);
      
      G(1:d * (n + 1)) = dFdC1(:) + reshape([dFdC2_k0; dFdC2_k; dFdC2_kn], ...
        d * (n + 1), 1);
    
      % Compute dL/dtk
      G(d * (n + 1) + 1:end) = 2 * n * sum((B(2:end-1,:) * C - ...
        data(2:end-1,:)) .* (Bn_1(2:end-1,:) * diff(C,1,1)),2);
    end    
  end

  function H = hessianfcn(X, lambda)
    
    % Retrieve the control point coordinates from X
    C = reshape(X(1:d * (n + 1)), n + 1, d);
    
    % Retrieve the nodes from X and add t0 and tm
    T = [0; X(d * (n + 1) + 1:end); 1];
    
    % Compute the Bernstein matrix
    B = (bsxfun(@power, T, 0:n) .* bsxfun(@power, 1 - T, n:-1:0)) * Cnk;
    
    % Compute the Bernstein matrix of order n-1
    Bn_1 = (bsxfun(@power, T, 0:n-1) .* bsxfun(@power, 1 - T, n-1:-1:0)) * Cn_1k;
    
    % Compute the Bernstein matrix of order n-2
    Bn_2 = (bsxfun(@power, T, 0:n-2) .* bsxfun(@power, 1 - T, n-2:-1:0)) * Cn_2k;
    
    H = zeros(pDim);
    
    % Compute d2F/dxkdxl
    
    % k = 0, l = 0
    H(1,1) = 2 * sum(B(:,1).^2) + 2 * beta * n^2 / (2 * n - 1);
    
    % k = 0, l = n
    H(n+1,1) = 2 * sum(B(:,1) .* B(:,end)) - 2 * beta * n^2 * ...
      fact_n_1^2 / fact_2n_1;
    
    % k = n, l = n
    H(n+1,n+1) = 2 * sum(B(:,end).^2) + 2 * beta * n^2 / (2 * n - 1);
    
    % k = 0, 0 < l < n
    H(2:n,1) = 2 * sum(bsxfun(@times, B(:,1), B(:,2:n)), 1) - ...
      2 * beta * n^2 * C4;
    
    % k = n, 0 < l < n
    H(n+1,2:n) = 2 * sum(bsxfun(@times, B(:,end), B(:,2:n)), 1) + ...
      2 * beta * n^2 * C5;
    
    % 0 < k < n, 0 < l < n
    H(2:n, 2:n) = 2 * B(:,2:end-1)' * B(:,2:end-1) + 2 * beta * n^2 * C6;
    
    blks = cell(d,1);
    [blks{:}] = deal(H(1:n+1,1:n+1));
    H(1:d * (n+1), 1:d * (n+1)) = blkdiag(blks{:});
    
    % Compute d2Fdtdx
    for iDim = 1:d
      offset = (iDim - 1) * (n + 1) + 1;
      
      % d2Fdtdx is a m x (n+1) matrix
      H(end-m+3:end, offset:offset+n) = 2 * B(2:end-1,:) .* ...
        (sum(bsxfun(@times, bsxfun(@rdivide, bsxfun(@minus, bsxfun(@plus, ...
        permute(0:n, [3, 1, 2]), 0:n), 2 * n * T(2:end-1)), T(2:end-1) .* ...
        (1-T(2:end-1))), permute(bsxfun(@times, B(2:end-1,:), C(:,iDim)'), ...
        [1, 3, 2])), 3) - bsxfun(@times, bsxfun(@rdivide, bsxfun(@minus, ...
        0:n, n * T(2:end-1)), T(2:end-1) .* (1-T(2:end-1))), ...
        data(2:end-1,iDim)));
    end
    
    % Compute d2Fdt2
    H(d * (n + 1) + 1:end, d * (n + 1) + 1:end) = 2 * diag(...
      n^2 * sum((Bn_1(2:end-1,:) * diff(C,1,1)).^2, 2) + n * (n-1) * ...
      sum((B(2:end-1,:) * C - data(2:end-1,:)) .* (Bn_2(2:end-1,:) * ...
      diff(C,2,1)),2));
    
    % assign the upper triangular part of H
    H = tril(H) + tril(H,-1)';
  end

  function [CON CONEQ CG CEQG] = fcon(X)
    % Retrieve the control point coordinates from X
    C = reshape(X(1:d * (n + 1)), n + 1, d);

    d1 = sum((data(1,:) - C(1,:)).^2) - maxDist2;
    d2 = sum((data(m,:) - C(n+1,:)).^2) - maxDist2;
    
    CON = [d1, d2];
        
    % There is no equality constraint.
    CONEQ = [];
    
    if nargout > 2
      CG = zeros(pDim,2);
      
      % Compute dG1/dxk
      
      % k = 0
      CG((0:(d-1)) * (n+1) + 1,1) = -2 * (data(1,:) - C(1,:))';
      
      % Compute dG2/dxk
      
      % k = n
      CG((1:d) * (n+1),2) =  -2 * (data(m,:) - C(n+1,:))';
      
      CEQG = [];
    end
  end
end

function reg = computeRegTermN1D2(C)

CC = num2cell(C);
[x0, x1, y0, y1] = CC{:};

reg = (x0 - x1)^2 + (y0 - y1)^2;
end

function reg = computeRegTermN1D3(C)

CC = num2cell(C);
[x0, x1, y0, y1, z0, z1] = CC{:};

reg = (x0 - x1)^2 + (y0 - y1)^2 + (z0 - z1)^2;
end

function reg = computeRegTermN2D2(C)

CC = num2cell(C);
[x0, x1, x2, y0, y1, y2] = CC{:};

reg = (4/3) * (x0^2 + x1^2 - x1 * x2 + x2^2 - x0 * (x1 + x2) + y0^2 - ...
  y0 * y1 + y1^2 - (y0 + y1) * y2 + y2^2);
end

function reg = computeRegTermN2D3(C)

CC = num2cell(C);
[x0, x1, x2, y0, y1, y2, z0, z1, z2] = CC{:};

reg = (4/3) * (x0^2 + x1^2 - x1 * x2 + x2^2 - x0 * (x1 + x2) + y0^2 - ... 
  y0 * y1 + y1^2 - (y0 + y1) * y2 + y2^2 + z0^2 - z0 * z1 + z1^2 - ...
  (z0 + z1) * z2 + z2^2);
end

function reg = computeRegTermN3D2(C)

CC = num2cell(C);
[x0, x1, x2, x3, y0, y1, y2, y3] = CC{:};

reg = .6 * (3 * x0^2 + 2 * x1^2 + 2 * x2^2 + x1 * (x2 - 2 * x3) - ...
  3 * x2 * x3 + 3 * x3^2 - x0 * (3 * x1 + 2 * x2 + x3) + 3 * y0^2 - ...
  3 * y0 * y1 + 2 * y1^2 - 2 * y0 * y2 + y1 * y2 + 2 * y2^2 - ...
  (y0 + 2 * y1 + 3 * y2) * y3 + 3 * y3^2);
end

function reg = computeRegTermN3D3(C)

CC = num2cell(C);
[x0, x1, x2, x3, y0, y1, y2, y3, z0, z1, z2, z3] = CC{:};

reg = .6 * (3 * x0^2 + 2 * x1^2 + 2 * x2^2 + x1 * (x2 - 2 * x3) - ...
  3 * x2 * x3 + 3 * x3^2 - x0 * (3 * x1 + 2 * x2 + x3) + 3 * y0^2 - ...
  3 * y0 * y1 + 2 * y1^2 - 2 * y0 * y2 + y1 * y2 + 2 * y2^2 - ...
  (y0 + 2 * y1 + 3 * y2) * y3 + 3 * y3^2 + 3 * z0^2 - 3 * z0 * z1 + ...
  2 * z1^2 - 2 * z0 * z2 + z1 * z2 + 2 * z2^2 - (z0 + 2 * z1 + 3 * z2) * ...
  z3 + 3 * z3^2);
end