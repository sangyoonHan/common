function [out,trend,imf]=preWhitening(TS,method)
%This function removes any deterministic component from the input time
%series TS
%
%Synopsis:
%         [out,trend]=preWhitening(TS,method)  
%
%Input: TS     - matrix(# of observations,# of variables)
%       method - string - 'imf' or 'ar' (Default is 'imf')
%
%Output
%       out   - detrend time series
%       trend - this is the sum of all derterministic components of the
%               signal
%       imf   - cell array with the intrinsic mode functions
%
%Reference
%Z. Wu, N. E. Huang, S. R. Long and C.-K. Peng, On the trend, detrending, and the
%variability of nonlinear and non-stationary time series, Proc. Natl. Acad. Sci. USA
%104 (2007) 14889?14894
%
% Marco Vilela, 2011

if nargin < 2
    method = 'imf';
end

[nObs,nVar] = size(TS);
max_order   = 8;
trend       = [];
out         = TS;
imf         = [];
h           = inf(2,nVar);

for i=1:nVar
    
    h(1,i) = kpsstest(TS(:,i));%Ho is stationary - 0 
    h(2,i) = vratiotest(TS(:,i),'alpha',0.01);%Ho is a random walk - 1
    
    if or(h(1,i),~h(2,i))
        switch method
            case 'ar'
                
                ts       = iddata(TS(:,i),[],1);
                model    = arxstruc(ts,ts,[1:max_order]');
                bestM    = selstruc(model,'aic');
                finalM   = ar(ts,bestM(1));
                IR       = polydata(finalM);
                out(:,i) = filter(IR,1,TS(:,i));
                
            case 'imf'
                [imf, flag] = empiricalModeDecomp( TS(:,i) ) ;
                range       =  find( cellfun(@(x) ~vratiotest(x) || kpsstest(x) ,imf ) ) ;
                if flag
                    for j=numel(range)-1:-1:1
                        trend = sum(cell2mat(imf( range(j:end)) ),2);
                        nTs   = TS(:,i) - trend;
                        h     = kpsstest(nTs);
                        if ~h
                            
                            out(:,i) = nTs;
                            break;
                            
                        end
                    end
                end
                
                if h
                    
                    out(:,i) = preWhitening(TS(:,i),1);
                    h        = kpsstest(out(:,i));
                    
                end
        end
    end
end
out = out - repmat(mean(out),nObs,1);