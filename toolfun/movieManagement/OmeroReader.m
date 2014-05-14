classdef  OmeroReader < Reader
    % Concrete implementation of MovieObject for a single movie
    properties
        imageID
    end
    
    properties (Transient = true)
        session
        image
        pixels
        rawPixelsStore
    end
    
    methods
        %% Constructor
        function obj = OmeroReader(imageID, session)
            obj.imageID = imageID;
            obj.setSession(session);
        end
        
        
        %% Dimensions functions
        function sizeX = getSizeX(obj, varargin)
            sizeX = obj.getPixels().getSizeX.getValue;
        end
        
        function sizeY = getSizeY(obj, varargin)
            sizeY = obj.getPixels().getSizeY.getValue;
        end
        
        function sizeC = getSizeC(obj, varargin)
            sizeC = obj.getPixels().getSizeC.getValue;
        end
        
        function sizeZ = getSizeZ(obj, varargin)
            sizeZ = obj.getPixels().getSizeZ.getValue;
        end
        
        function sizeT = getSizeT(obj, varargin)
            sizeT = obj.getPixels().getSizeT.getValue;
        end
        
        function session = getSession(obj)
            % Check session is not empty
            assert(~isempty(obj.session), 'No session created');
            session =  obj.session;
        end
        
        function setSession(obj, session)
            % Check input
            ip = inputParser;
            ip.addRequired('session', @MovieObject.isOmeroSession);
            ip.parse(session);
            
            obj.session = session;
        end
        
        function bitDepth = getBitDepth(obj, varargin)
            pixelType = obj.getPixels().getPixelsType();
            pixelsService = obj.getSession().getPixelsService();
            bitDepth = pixelsService.getBitDepth(pixelType);
        end
        
        %% Image/Channel name functions
        function fileNames = getImageFileNames(obj, iChan, varargin)
            % Generate image file names
            basename = sprintf('Image%g_c%d_t', obj.imageID, iChan);
            fileNames = arrayfun(@(t) [basename num2str(t, ['%0' num2str(floor(log10(obj.getSizeT))+1) '.f']) '.tif'],...
                1:obj.getSizeT,'Unif',false);
            
        end
        
        function chanNames = getChannelNames(obj, iChan)
            chanNames = arrayfun(@(x) ['Image ' num2str(obj.imageID) ...
                ': Channel ' num2str(x)], iChan, 'UniformOutput', false);
        end
        
        
        %% Image loading function
        function I = loadImage(obj, c, t, varargin)
            
            ip = inputParser;
            ip.addRequired('c', @(x) isscalar(x) && ismember(x, 1 : obj.getSizeC()));
            ip.addRequired('t', @(x) isscalar(x) && ismember(x, 1 : obj.getSizeT()));
            ip.addOptional('z', 1, @(x) isscalar(x) && ismember(x, 1 : obj.getSizeZ()));
            ip.parse(c, t, varargin{:});
            
            % Test session integrity
            store = obj.getRawPixelsStore();
            I = toMatrix(store.getPlane(ip.Results.z - 1, c - 1, t - 1),...
                obj.getPixels())';
        end
        
        function delete(obj)
            if ~isempty(obj.rawPixelsStore),
                obj.rawPixelsStore.close()
            end
        end
        
        %% Helper functions
        function image = getImage(obj)
            if isempty(obj.image),
                obj.image = getImages(obj.getSession(), obj.imageID);
            end
            image = obj.image;
        end
        
        function pixels = getPixels(obj)
            pixels = obj.getImage().getPrimaryPixels();
        end
        
        function store = getRawPixelsStore(obj)
            if isempty(obj.rawPixelsStore)
                store = obj.getSession().createRawPixelsStore();
                store.setPixelsId(obj.getPixels().getId().getValue(), false);
                obj.rawPixelsStore = store;
            else
                store = obj.rawPixelsStore;
            end
            
        end
    end
end