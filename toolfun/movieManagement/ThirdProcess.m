classdef ThirdProcess < Process
% A concrete process for mask process info
    properties (SetAccess = private, GetAccess = public)
    % SetAccess = private - cannot change the values of variables outside object
    % GetAccess = public - can get the values of variables outside object without
    % definging accessor functions
       maskPaths_

    end
    
    methods (Access = public)
        function obj = ThirdProcess (owner, maskPaths, ...
                funName, funParams)
           % Construntor of class MaskProcess
           if nargin == 0
              super_args = {};
           else
               super_args{1} = owner;
               super_args{2} = 'Third'; 
           end
           % Call the supercalss constructor with empty cell array (no
           % argument) if nargin == 0
           obj = obj@Process(super_args{:});
           if nargin > 0
              obj.maskPaths_ = maskPaths;
              obj.funName_ = funName;
              if isnumeric (funParams)
                obj.funParams_ = funParams;
              else
                obj.funParams_ = str2double(funParams);
              end
           end
        end
        function sanityCheck(obj) % throw exception
            % Sanity Check
            if obj.funParams_ < 0
                error('lccb:set:fatal','Sanity check of third process goes wrong\n\n');
            end
            % Check mask path for each channel
            % ... ...
        end
    end
    methods (Static)
        function text = getHelp(obj)
           text = 'Third process cannot swim!! help~~ help~~~'; 
        end
    end
end