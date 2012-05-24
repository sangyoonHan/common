tracksDir = '/home/kj35/files/LCCB/receptors/Galbraiths/data/talinAndCellEdge/120516_Cs2C3_Talin/analysisTalin/tracks/';
diffDir = '/home/kj35/files/LCCB/receptors/Galbraiths/data/talinAndCellEdge/120516_Cs2C3_Talin/analysisTalin/diffusion/';

tracksFileName = {...
    'tracks1All_01.mat',...
    'tracks1All_02.mat',...
    'tracks1All_03.mat',...
    'tracks1All_04.mat',...
    'tracks1All_05.mat',...
    'tracks1All_06.mat',...
    'tracks1All_07.mat',...
    'tracks1All_08.mat',...
    'tracks1All_09.mat',...
    'tracks1All_10.mat',...
    'tracks1All_11.mat',...
    'tracks1All_12.mat',...
    };

diffFileName = {...
    'diffusion1All_01.mat',...
    'diffusion1All_02.mat',...
    'diffusion1All_03.mat',...
    'diffusion1All_04.mat',...
    'diffusion1All_05.mat',...
    'diffusion1All_06.mat',...
    'diffusion1All_07.mat',...
    'diffusion1All_08.mat',...
    'diffusion1All_09.mat',...
    'diffusion1All_10.mat',...
    'diffusion1All_11.mat',...
    'diffusion1All_12.mat',...
    };

numFiles = length(tracksFileName);

%initialize temporary structures
tmpD = repmat(struct('field',[]),numFiles,1);
tmpT = tmpD;

for j = 1 : numFiles
    
    disp(num2str(j));
    
    %get tracks for this time interval
    load(fullfile(tracksDir,tracksFileName{j}));
    
    %do diffusion analysis
    diffAnalysisRes = trackDiffusionAnalysis1(tracksFinal,1,2,1,[0.05 0.1],0,0);
    
    %save diffusion analysis of this time interval
    save(fullfile(diffDir,diffFileName{j}),'diffAnalysisRes');
    
    %store tracks and diffusion analysis in temporary structures
    tmpD(j).field = diffAnalysisRes;
    tmpT(j).field = tracksFinal;
    
end

%save combined diffusion analysis
diffAnalysisRes = vertcat(tmpD.field);
save(fullfile(diffDir,'diffAnalysis1AllFrames'),'diffAnalysisRes');

%save combined tracks
tracksFinal = vertcat(tmpT.field);
save(fullfile(tracksDir,'tracks1AllFrames'),'tracksFinal');
