classdef MotionAnalysisProcess < DataProcessingProcess
    % A concrete class associated to the comet detection
    %
    % Sebastien Besson, March 2012

    methods (Access = public)
        function obj = MotionAnalysisProcess(owner, varargin)            
            if nargin == 0
                super_args = {};
            else
                % Input check
                ip = inputParser;
                ip.addRequired('owner',@(x) isa(x,'MovieData'));
                ip.addOptional('outputDir',owner.outputDirectory_,@ischar);
                ip.addOptional('funParams',[],@isstruct);
                ip.parse(owner,varargin{:});
                outputDir = ip.Results.outputDir;
                funParams = ip.Results.funParams;
                
                super_args{1} = owner;
                super_args{2} = MotionAnalysisProcess.getName;
                super_args{3} = @analyzeMovieMotion;
                if isempty(funParams)  % Default funParams
                    funParams = MotionAnalysisProcess.getDefaultParams(owner,outputDir);
                end
                super_args{4} = funParams;  
            end
            
            obj = obj@DataProcessingProcess(super_args{:});
        end
        function varargout = loadChannelOutput(obj,iChan,varargin)
            
            % Input check
            outputList = {'diffAnalysisRes'};
            ip =inputParser;
            ip.addRequired('iChan',@(x) isscalar(x) && obj.checkChanNum(x));
            ip.addOptional('iFrame',1:obj.owner_.nFrames_,@(x) all(obj.checkFrameNum(x)));
            ip.addParamValue('output',outputList,@(x) all(ismember(x,outputList)));
            ip.parse(iChan,varargin{:})
            iFrame = ip.Results.iFrame;
            output = ip.Results.output;
            if ischar(output),output={output}; end
            
            % Data loading
            s = load(obj.outFilePaths_{1,iChan},output{:});
            for i=1:numel(output),varargout{i}=s.(output{i}); end
        end
    end
    methods (Static)
        
        function name = getName()
            name = 'Motion Analysis';
        end
        function h = GUI()
            h = @motionAnalysisProcessGUI;
        end
        
        function alpha = getAlphaValues()
           alpha=[0.01 0.05 0.1 0.2];
        end
        
        function methods = getConfinementRadiusMethods()
            methods(1).type=0;
            methods(1).name='Mean positional standard deviation';
            methods(2).type=1;
            methods(2).name='Minimum positional standard deviation';
            methods(3).type=2;
            methods(3).name='Rectangle approximation';
        end
        
        function funParams = getDefaultParams(owner,varargin)
            % Input check
            ip=inputParser;
            ip.addRequired('owner',@(x) isa(x,'MovieData'));
            ip.addOptional('outputDir',owner.outputDirectory_,@ischar);
            ip.parse(owner, varargin{:})
            outputDir=ip.Results.outputDir;
            
            % Set default parameters
            funParams.ChannelIndex = 1 : numel(owner.channels_);
            funParams.OutputDirectory = [outputDir  filesep 'meta'];
            funParams.probDim = 2;
            funParams.checkAsym = 0;
            funParams.alphaValues = [0.05 0.1];
            funParams.confRadMin=0;
        end
    end    
end