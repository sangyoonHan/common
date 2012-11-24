function varargout = nucleiDetectionProcessGUI(varargin)
% nucleiDetectionProcessGUI M-file for nucleiDetectionProcessGUI.fig
%      nucleiDetectionProcessGUI, by itself, creates a new nucleiDetectionProcessGUI or raises the existing
%      singleton*.
%
%      H = nucleiDetectionProcessGUI returns the handle to a new nucleiDetectionProcessGUI or the handle to
%      the existing singleton*.
%
%      nucleiDetectionProcessGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in nucleiDetectionProcessGUI.M with the given input arguments.
%
%      nucleiDetectionProcessGUI('Property','Value',...) creates a new nucleiDetectionProcessGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before nucleiDetectionProcessGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to nucleiDetectionProcessGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help nucleiDetectionProcessGUI

% Last Modified by GUIDE v2.5 16-Dec-2011 15:45:34

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @nucleiDetectionProcessGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @nucleiDetectionProcessGUI_OutputFcn, ...
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


% --- Executes just before nucleiDetectionProcessGUI is made visible.
function nucleiDetectionProcessGUI_OpeningFcn(hObject, eventdata, handles, varargin)

processGUI_OpeningFcn(hObject, eventdata, handles, varargin{:},'initChannel',1);

% ---------------------- Channel Setup -------------------------
userData = get(handles.figure1, 'UserData');
funParams = userData.crtProc.funParams_;

% Set parameters
set(handles.edit_radius,'String',funParams.radius);
edgeFilters=NucleiDetectionProcess.getFilters;
set(handles.popupmenu_edgeFilter,'String',edgeFilters,...
    'Value',find(strcmp(funParams.edgeFilter,edgeFilters)));

set(handles.edit_sigma,'String',funParams.sigma);
set(handles.edit_p,'String',funParams.p);
set(handles.checkbox_useDblLog,'Value',funParams.useDblLog);


set(handles.edit_firstFrame, 'String', funParams.firstFrame);
set(handles.edit_lastFrame, 'String', funParams.lastFrame);
set(handles.text_nFrames, 'String', ['(Totally ' num2str(userData.MD.nFrames_) ' frames in the movie)'])

% Update user data and GUI data
handles.output = hObject;
set(hObject, 'UserData', userData);
guidata(hObject, handles);

% --- Outputs from this function are returned to the command line.
function varargout = nucleiDetectionProcessGUI_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pushbutton_cancel.
function pushbutton_cancel_Callback(hObject, eventdata, handles)
% Delete figure
delete(handles.figure1);


% --- Executes on button press in pushbutton_done.
function pushbutton_done_Callback(hObject, eventdata, handles)
% Call back function of 'Apply' button
userData = get(handles.figure1, 'UserData');

% -------- Check user input --------
if isempty(get(handles.listbox_selectedChannels, 'String'))
   errordlg('Please select at least one input channel from ''Available Channels''.','Setting Error','modal') 
    return;
end
channelIndex = get (handles.listbox_selectedChannels, 'Userdata');
funParams.ChannelIndex = channelIndex;

radius = str2double(get(handles.edit_radius, 'String'));
if isnan(radius) || radius <0
    errordlg(['Please provide a valid value for ' get(handles.text_radius,'String')...
        '.'],'Setting Error','modal')
    return
end
funParams.radius = radius;

p = str2double(get(handles.edit_p, 'String'));
if isnan(p ) || p  <0
    errordlg(['Please provide a valid value for ' get(handles.text_p,'String')...
        '.'],'Setting Error','modal')
    return
end
funParams.p  = p ;
funParams.useDblLog = get(handles.checkbox_useDblLog,'Value');

props=get(handles.popupmenu_edgeFilter, {'String','Value'});
funParams.edgeFilter=props{1}{props{2}};
if strcmp(funParams.edgeFilter,'canny')
    sigma = str2double(get(handles.edit_sigma, 'String'));
    if isnan(sigma) || sigma <0
        errordlg(['Please provide a valid value for ' get(handles.text_sigma,'String')...
            '.'],'Setting Error','modal')
        return
    end
    funParams.sigma  = sigma;
end


firstFrame=str2double(get(handles.edit_firstFrame, 'String'));
if isnan(firstFrame) || firstFrame<1 ||round(firstFrame)~=firstFrame
    errordlg('Please provide a valid value for the frame range to analyze.','Setting Error','modal')
    return
end
funParams.firstFrame=firstFrame;

lastFrame=str2double(get(handles.edit_lastFrame, 'String'));
if isnan(lastFrame) || lastFrame>userData.MD.nFrames_ ||...
        lastFrame<firstFrame|| round(lastFrame)~=lastFrame
    errordlg('Please provide a valid value for the frame range to analyze.','Setting Error','modal')
    return
end
funParams.lastFrame=lastFrame;

if  lastFrame == userData.MD.nFrames_
     setLastFrame =@(x) parseProcessParams(x, struct('lastFrame',...
        x.owner_.nFrames_));
else
    setLastFrame =@(x) parseProcessParams(x, struct('lastFrame',...
        min(x.funParams_.lastFrame,x.owner_.nFrames_)));
end

processGUI_ApplyFcn(hObject, eventdata, handles,funParams,{setLastFrame});


% --- Executes during object deletion, before destroying properties.
function figure1_DeleteFcn(hObject, eventdata, handles)
% Notify the package GUI that the setting panel is closed
userData = get(handles.figure1, 'UserData');

if ishandle(userData.helpFig), delete(userData.helpFig); end

set(handles.figure1, 'UserData', userData);
guidata(hObject,handles);


% --- Executes on key press with focus on pushbutton_done and none of its controls.
function pushbutton_done_KeyPressFcn(hObject, eventdata, handles)

if strcmp(eventdata.Key, 'return')
    pushbutton_done_Callback(handles.pushbutton_done, [], handles);
end

% --- Executes on key press with focus on figure1 and none of its controls.
function figure1_KeyPressFcn(hObject, eventdata, handles)

if strcmp(eventdata.Key, 'return')
    pushbutton_done_Callback(handles.pushbutton_done, [], handles);
end
