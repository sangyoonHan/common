classdef DetectionProcess < ImageAnalysisProcess
    % An abstract class for all detection processes with an output
    % structure compatible with the tracker
    
    % Chuangang Ren, 11/2010
    % Sebastien Besson (last modified May 2012)
    % Mark Kittisopikul, Nov 2014, Added channelOutput cache
    % Andrew R. Jamieson, mar 2017, adding 3D support.
    
    methods(Access = public)
        
        function obj = DetectionProcess(owner, name, funName, funParams )
            
            if nargin == 0
                super_args = {};
            else
                super_args{1} = owner;
                super_args{2} = name;
            end
            
            obj = obj@ImageAnalysisProcess(super_args{:});
            
            if nargin > 2
                obj.funName_ = funName;
            end
            if nargin > 3
                obj.funParams_ = funParams;
            end
        end
        
        function status = checkChannelOutput(obj,iChan)
            
            %Checks if the selected channels have valid output files
            nChan = numel(obj.owner_.channels_);
            if nargin < 2 || isempty(iChan), iChan = 1:nChan; end
            
            status=  ismember(iChan,1:nChan) & ....
                arrayfun(@(x) exist(obj.outFilePaths_{1,x},'file'),iChan);
        end

        function h=draw(obj,iChan,varargin)
            h = obj.draw@ImageAnalysisProcess(iChan,varargin{:},'useCache',true);
        end
        
        function varargout = loadChannelOutput(obj,iChan,varargin)
            
            % Input check
            outputList = {'movieInfo'};
            ip =inputParser;
            ip.addRequired('iChan',@(x) isscalar(x) && obj.checkChanNum(x));
            ip.addOptional('iFrame',1:obj.owner_.nFrames_,@(x) all(obj.checkFrameNum(x)));
            ip.addParamValue('useCache',false,@islogical);
            ip.addParamValue('output',outputList,@(x) all(ismember(x,outputList)));
            ip.parse(iChan,varargin{:})
            iFrame = ip.Results.iFrame;
            output = ip.Results.output;
            if ischar(output),output={output}; end
            
            % Data loading
            % load outFilePaths_{1,iChan}
            %
            s = cached.load(obj.outFilePaths_{1,iChan}, '-useCache', ip.Results.useCache, output{:});
           
            if numel(ip.Results.iFrame)>1,
                varargout{1}=s.(output{1});
            else
                varargout{1}=s.(output{1})(iFrame);
            end
        end
        function output = getDrawableOutput(obj)
            colors = hsv(numel(obj.owner_.channels_));
            output(1).name='Objects';
            output(1).var='movieInfo';
            output(1).formatData=@DetectionProcess.formatOutput;
            output(1).type='overlay';
            output(1).defaultDisplayMethod=@(x) LineDisplay('Marker','o',...
                'LineStyle','none','Color',colors(x,:));
        end  
        
    end
    methods(Static)

        function name = getName()
            name = 'Detection';
        end

        function h = GUI()
            h = @abstractProcessGUI;
        end

        function procClasses = getConcreteClasses(varargin)

            procClasses = ...
                {@SubResolutionProcess;
                 @CometDetectionProcess;
                 @AnisoGaussianDetectionProcess;
                 @NucleiDetectionProcess;
                 @PointSourceDetectionProcess;
                 @PointSourceDetectionProcess3D;
                };

            % If input, check if 2D or 3D movie(s).
            ip =inputParser;
            ip.addOptional('MO', [], @(x) isa(x,'MovieData') || isa(x,'MovieList'));
            ip.parse(varargin{:});
            MO = ip.Results.MO;
            
            if ~isempty(MO)
                if isa(MO,'MovieList')
                    MD = MO.getMovie(1);
                elseif length(MO) > 1
                    MD = MO(1);
                else
                    MD = MO;
                end                
            end

            if isempty(MD)
               warning('MovieData properties not specified (2D vs. 3D)');
               disp('Displaying both 2D and 3D Detection processes');
            elseif MD.is3D
                disp('Detected 3D movie');
                disp('Displaying 3D Detection processes only');
                procClasses(1:end-1) = [];
            elseif ~MD.is3D
                disp('Detected 2D movie');
                disp('Displaying 2D Detection processes only');
                procClasses(6) = [];
            end
            procClasses = cellfun(@func2str, procClasses, 'Unif', 0);
        end
        
        function y = formatOutput(x)
            % Format output in xy coordinate system
            y = DetectionProcess.formatOutput2D(x);
        end

        function y = formatOutput2D(x)
            % Format output in xy coordinate system
            if isempty(x.xCoord)
                y = NaN(1,2);
            else
                y = horzcat(x.xCoord(:,1),x.yCoord(:,1));
            end
        end

        function y = formatOutput3D(x)
            if isempty(x)
                y = NaN(1,3);
            else
                y = x;
            end
        end

    end
end
