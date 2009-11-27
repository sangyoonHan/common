
%% define batch job locations

%image locations
imageDir = {'/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat02/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat04/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat06/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat08/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat10/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat12/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat14/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat16/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat18/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat20/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat22/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat24/'};

%file name bases
filenameBase = {'1019_Q36_SMI_count_',...
    '1019_Q36_SMI_count_',...
    '1019_Q36_SMI_count_',...
    '1019_Q36_SMI_count_',...
    '1019_Q36_SMI_count_',...
    '1019_Q36_SMI_count_',...
    '1019_Q36_SMI_count_',...
    '1019_Q36_SMI_count_',...
    '1019_Q36_SMI_count_',...
    '1019_Q36_SMI_count_',...
    '1019_Q36_SMI_count_',...
    '1019_Q36_SMI_count_'};

%directory for saving results
saveResDir = {'/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat02/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat04/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat06/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat08/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat10/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat12/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat14/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat16/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat18/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat20/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat22/',...
    '/home/kj35/.gvfs/orchestra on files.med.harvard.edu/groups/lccb-receptors/Hiro/091019_Q36_SMI_count/Llat24/'};


%% calculate number of movies
numMovies = length(filenameBase);

for iMovie = 1 : numMovies
    
    %display movie number
    disp(['Movie ' num2str(iMovie) ' / ' num2str(numMovies) ' ...'])
    
    %% movie information
    movieParam.imageDir = imageDir{iMovie}; %directory where images are
    movieParam.filenameBase = filenameBase{iMovie}; %image file name base
    movieParam.firstImageNum = 1; %number of first image in movie
    movieParam.lastImageNum = 10; %number of last image in movie
    movieParam.digits4Enum = 4; %number of digits used for frame enumeration (1-4).
    
    %% detection parameters
    detectionParam.psfSigma = 2.1; %point spread function sigma (in pixels)
    detectionParam.testAlpha = struct('alphaR',5e-5,'alphaA',5e-6,'alphaD',5e-6,'alphaF',0); %alpha-values for detection statistical tests
    detectionParam.visual = 0; %1 to see image with detected features, 0 otherwise
    detectionParam.doMMF = 1; %1 if mixture-model fitting, 0 otherwise
    detectionParam.bitDepth = 16; %Camera bit depth
    detectionParam.alphaLocMax = 0.05; %alpha-value for initial detection of local maxima
    detectionParam.numSigmaIter = 0; %maximum number of iterations for PSF sigma estimation
    detectionParam.integWindow = 0; %number of frames before and after a frame for time integration
    
    %% save results
    saveResults.dir = saveResDir{iMovie}; %directory where to save input and output
    saveResults.filename = 'detection1.mat'; %name of file where input and output are saved
    % saveResults = 0;
    
    %% run the detection function
    [movieInfo,exceptions,localMaxima,background,psfSigma] = ...
        detectSubResFeatures2D_StandAlone(movieParam,detectionParam,saveResults);
    
end
