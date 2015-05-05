function varargout = addMovieROIMaskGUI(varargin)
% addMovieROIMaskGUI M-file for addMovieROIMaskGUI.fig
%      addMovieROIMaskGUI, by itself, creates a new addMovieROIMaskGUI or raises the existing
%      singleton*.
%
%      H = addMovieROIMaskGUI returns the handle to a new addMovieROIMaskGUI or the handle to
%      the existing singleton*.
%
%      addMovieROIMaskGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in addMovieROIMaskGUI.M with the given input arguments.
%
%      addMovieROIMaskGUI('Property','Value',...) creates a new addMovieROIMaskGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before addMovieROIMaskGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to addMovieROIMaskGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help addMovieROIMaskGUI

% Last Modified by GUIDE v2.5 24-Mar-2015 13:16:14

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @addMovieROIMaskGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @addMovieROIMaskGUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before addMovieROIMaskGUI is made visible.
function addMovieROIMaskGUI_OpeningFcn(hObject,eventdata,handles,varargin)

% Check input
% The mainFig and procID should always be present
% procCOnstr and procName should only be present if the concrete process
% initation is delegated from an abstract class. Else the constructor will
% be directly read from the package constructor list.
ip = inputParser;
ip.addRequired('hObject',@ishandle);
ip.addRequired('eventdata',@(x) isstruct(x) || isempty(x));
ip.addRequired('handles',@isstruct);
ip.addOptional('MD',[],@(x)isa(x,'MovieData'));
ip.addParamValue('mainFig',-1,@ishandle);
ip.parse(hObject,eventdata,handles,varargin{:});

userData.MD =ip.Results.MD;
userData.mainFig =ip.Results.mainFig;

% Set up copyright statement
set(handles.text_copyright, 'String', getLCCBCopyright());

% Set up available input channels
set(handles.listbox_selectedChannels,'String',userData.MD.getChannelPaths(), ...
    'UserData',1:numel(userData.MD.channels_));

% Save the image directories and names (for cropping preview)
userData.nFrames = userData.MD.nFrames_;
userData.imPolyHandle.isvalid=0;
userData.ROI = [];
userData.previewFig=-1;
userData.helpFig=-1;

% Read the first image and update the sliders max value and steps
userData.chanIndex = 1;
set(handles.edit_frameNumber,'String',1);
set(handles.slider_frameNumber,'Min',1,'Value',1,'Max',userData.nFrames,...
    'SliderStep',[1/max(1,double(userData.nFrames-1))  10/max(1,double(userData.nFrames-1))]);
userData.imIndx=1;
userData.imData=mat2gray(userData.MD.channels_(userData.chanIndex).loadImage(userData.imIndx));
    
set(handles.listbox_selectedChannels,'Callback',@(h,event) update_data(h,event,guidata(h)));

userData_main = get(ip.Results.mainFig, 'UserData');
set(handles.figure1,'CurrentAxes',handles.axes_help);
Img = image(userData_main.questIconData);
set(gca, 'XLim',get(Img,'XData'),'YLim',get(Img,'YData'),...
	'visible','off','YDir','reverse');
set(Img,'ButtonDownFcn',@icon_ButtonDownFcn,...
  	'UserData', struct('class', mfilename))
    
% Choose default command line output for addMovieROIMaskGUI
handles.output = hObject;

% Update user data and GUI data
set(hObject, 'UserData', userData);
guidata(hObject, handles);
update_data(hObject,eventdata,handles);


% --- Outputs from this function are returned to the command line.
function varargout = addMovieROIMaskGUI_OutputFcn(~, ~, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes on button press in pushbutton_cancel.
function pushbutton_cancel_Callback(~, ~, handles)
% Delete figure
delete(handles.figure1);

% --- Executes during object deletion, before destroying properties.
function figure1_DeleteFcn(hObject, ~, handles)
% Notify the package GUI that the setting panel is closed
userData = get(handles.figure1, 'UserData');

if ~isempty(userData)
    
    if ishandle(userData.helpFig), delete(userData.helpFig); end
    if ishandle(userData.previewFig), delete(userData.previewFig); end
    
    set(handles.figure1, 'UserData', userData);
    guidata(hObject,handles);
end

% --- Executes on key press with focus on pushbutton_save and none of its controls.
function pushbutton_save_KeyPressFcn(~, eventdata, handles)

if strcmp(eventdata.Key, 'return')
    pushbutton_done_Callback(handles.pushbutton_save, [], handles);
end

% --- Executes on key press with focus on figure1 and none of its controls.
function figure1_KeyPressFcn(~, eventdata, handles)

if strcmp(eventdata.Key, 'return')
    pushbutton_done_Callback(handles.pushbutton_save, [], handles);
end

 % --- Executes on button press in checkbox_preview.
function update_data(hObject, eventdata, handles)
userData = get(handles.figure1, 'UserData');

% Retrieve the channel index
props=get(handles.listbox_selectedChannels,{'UserData','Value'});
chanIndex = props{1}(props{2});
imIndx = get(handles.slider_frameNumber,'Value');

% Load a new image if either the image number or the channel has been changed
if (chanIndex~=userData.chanIndex) ||  (imIndx~=userData.imIndx)
    % Update image flag and dat
    userData.imData=mat2gray(userData.MD.channels_(chanIndex).loadImage(imIndx));
    userData.updateImage=1;
    userData.chanIndex=chanIndex;
    userData.imIndx=imIndx;
        
    % Update roi
    if userData.imPolyHandle.isvalid
        userData.ROI=getPosition(userData.imPolyHandle);
    end    
else
    userData.updateImage=0;
end


% Create figure if non-existing or closed
if ~isfield(userData, 'previewFig') || ~ishandle(userData.previewFig)
    userData.previewFig = figure('NumberTitle','off','Name',...
        'Select the region of interest','DeleteFcn',@close_previewFig,...
        'UserData',handles.figure1);
    axes('Position',[.05 .05 .9 .9]);
    userData.newFigure = 1;
else
    figure(userData.previewFig);
    userData.newFigure = 0;
end

% Retrieve the image object handle
imHandle =findobj(userData.previewFig,'Type','image');
if userData.newFigure || userData.updateImage
    if isempty(imHandle)
        imHandle=imshow(userData.imData);
        axis off;
    else
        set(imHandle,'CData',userData.imData);
    end
end

if userData.imPolyHandle.isvalid
    % Update the imPoly position
    setPosition(userData.imPolyHandle,userData.ROI)
else
    % Create a new imPoly object and store the handle
    if ~isempty(userData.ROI)
        userData.imPolyHandle = impoly(get(imHandle,'Parent'));
    else
        userData.imPolyHandle = impoly(get(imHandle,'Parent'),userData.ROI);
    end
    fcn = makeConstrainToRectFcn('impoly',get(imHandle,'XData'),get(imHandle,'YData'));
    setPositionConstraintFcn(userData.imPolyHandle,fcn);
end

set(handles.figure1, 'UserData', userData);
guidata(hObject,handles);

function close_previewFig(hObject, eventdata)
handles = guidata(get(hObject,'UserData'));
userData=get(handles.figure1,'UserData');
userData.ROI=getPosition(userData.imPolyHandle);
set(handles.figure1,'UserData',userData);
update_data(hObject, eventdata, handles);

% --- Executes on slider movement.
function frameNumberEdition_Callback(hObject, eventdata, handles)
userData = get(handles.figure1, 'UserData');

% Retrieve the value of the selected image
if strcmp(get(hObject,'Tag'),'edit_frameNumber')
    frameNumber = str2double(get(handles.edit_frameNumber, 'String'));
else
    frameNumber = get(handles.slider_frameNumber, 'Value');
end
frameNumber=round(frameNumber);

% Check the validity of the frame values
if isnan(frameNumber)
    warndlg('Please provide a valid frame value.','Setting Error','modal');
end
frameNumber = min(max(frameNumber,1),userData.nFrames);

% Store value
set(handles.slider_frameNumber,'Value',frameNumber);
set(handles.edit_frameNumber,'String',frameNumber);

% Save data and update graphics
set(handles.figure1, 'UserData', userData);
guidata(hObject, handles);
update_data(hObject,eventdata,handles);

% --- Executes on button press in pushbutton_save.
function pushbutton_save_Callback(hObject, eventdata, handles)

userData = get(handles.figure1, 'UserData');

% Read ROI if crop window is still visible
if userData.imPolyHandle.isvalid
    userData.ROI=getPosition(userData.imPolyHandle);
    set(handles.figure1,'UserData',userData);
end
update_data(hObject,eventdata,handles);

% Create ROI mask and save it in the outputDirectory
userData = get(handles.figure1, 'UserData');
mask=createMask(userData.imPolyHandle);
maskPath = fullfile(userData.MD.outputDirectory_,'roiMask.tif');
imwrite(mask,maskPath);

% Create a new region of interest and save the object
userData.MD.setROIMaskPath(maskPath);   
userData.MD.save();

% Delete current window
delete(handles.figure1)