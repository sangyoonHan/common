function varargout = pointSourceDetectionProcessGUI(varargin)
% anisoGaussianDetectionProcessGUI M-file for anisoGaussianDetectionProcessGUI.fig
%      anisoGaussianDetectionProcessGUI, by itself, creates a new anisoGaussianDetectionProcessGUI or raises the existing
%      singleton*.
%
%      H = anisoGaussianDetectionProcessGUI returns the handle to a new anisoGaussianDetectionProcessGUI or the handle to
%      the existing singleton*.
%
%      anisoGaussianDetectionProcessGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in anisoGaussianDetectionProcessGUI.M with the given input arguments.
%
%      anisoGaussianDetectionProcessGUI('Property','Value',...) creates a new anisoGaussianDetectionProcessGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before anisoGaussianDetectionProcessGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to anisoGaussianDetectionProcessGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help anisoGaussianDetectionProcessGUI

% Last Modified by GUIDE v2.5 13-Aug-2013 16:29:16

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @pointSourceDetectionProcessGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @pointSourceDetectionProcessGUI_OutputFcn, ...
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


% --- Executes just before anisoGaussianDetectionProcessGUI is made visible.
function pointSourceDetectionProcessGUI_OpeningFcn(hObject, eventdata, handles, varargin)

processGUI_OpeningFcn(hObject, eventdata, handles, varargin{:},'initChannel',1);

% Set-up parameters
userData=get(handles.figure1,'UserData');
funParams = userData.crtProc.funParams_;

% Set-up parameters
userData.numParams = {'filterSigma', 'alpha','Mode','MaxMixtures','RedundancyRadius'};

for i =1 : numel(userData.numParams)
    paramName = userData.numParams{i};        
    set(handles.(['edit_' paramName]), 'String', funParams.(paramName));
end

%Set the checkbox separately since it's not a string
set(handles.edit_FitMixtures,'Value',funParams.FitMixtures);


% Update GUI user data
set(handles.figure1, 'UserData', userData);
handles.output = hObject;
guidata(hObject, handles);

% --- Outputs from this function are returned to the command line.
function varargout = pointSourceDetectionProcessGUI_OutputFcn(~, ~, handles) 
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

if isfield(userData, 'helpFig') && ishandle(userData.helpFig)
   delete(userData.helpFig) 
end

set(handles.figure1, 'UserData', userData);
guidata(hObject,handles);


% --- Executes on key press with focus on pushbutton_done and none of its controls.
function pushbutton_done_KeyPressFcn(~, eventdata, handles)

if strcmp(eventdata.Key, 'return')
    pushbutton_done_Callback(handles.pushbutton_done, [], handles);
end

% --- Executes on key press with focus on figure1 and none of its controls.
function figure1_KeyPressFcn(~, eventdata, handles)

if strcmp(eventdata.Key, 'return')
    pushbutton_done_Callback(handles.pushbutton_done, [], handles);
end

% --- Executes on button press in pushbutton_done.
function pushbutton_done_Callback(hObject, eventdata, handles)

% -------- Check user input --------

if isempty(get(handles.listbox_selectedChannels, 'String'))
    errordlg('Please select at least one input channel from ''Available Channels''.','Setting Error','modal')
    return;
end

% Retrieve GUI-defined parameters
channelIndex = get(handles.listbox_selectedChannels, 'Userdata');
funParams.ChannelIndex = channelIndex;

% Retrieve detection parameters
userData = get(handles.figure1, 'UserData');
for i = 1:numel(userData.numParams)
    paramName = userData.numParams{i};
    switch paramName

    case 'Mode'            
        value = get(handles.(['edit_' paramName]),'String');

    otherwise
        value = str2double(get(handles.(['edit_' paramName]),'String'));

        if isnan(value) || value < 0
            errordlg(['Please enter a valid value for '...
                get(handles.(['text_' paramName]),'String') '.'],...
                'Setting Error','modal')
            return;
        end
            
    end
    funParams.(paramName)=value; 
end

funParams.FitMixtures = get(handles.edit_FitMixtures,'Value') > 0;


% Add 64-bit warning
is64bit = ~isempty(regexp(computer ,'64$', 'once'));
if ~is64bit
    warndlg(['Your Matlab version is not detected as 64-bit. Please note '....
        'the anisotropic Gaussian detection uses compiled MEX files which '...
        'are not provided for 32-bit.'],...
        'Setting Error','modal');
end

processGUI_ApplyFcn(hObject, eventdata, handles,funParams);



function edit_Mode_Callback(hObject, eventdata, handles)
% hObject    handle to edit_Mode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_Mode as text
%        str2double(get(hObject,'String')) returns contents of edit_Mode as a double


% --- Executes during object creation, after setting all properties.
function edit_Mode_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_Mode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in edit_FitMixtures.
function edit_FitMixtures_Callback(hObject, eventdata, handles)
% hObject    handle to edit_FitMixtures (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of edit_FitMixtures



function edit_MaxMixtures_Callback(hObject, eventdata, handles)
% hObject    handle to edit_MaxMixtures (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_MaxMixtures as text
%        str2double(get(hObject,'String')) returns contents of edit_MaxMixtures as a double


% --- Executes during object creation, after setting all properties.
function edit_MaxMixtures_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_MaxMixtures (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_RedundancyRadius_Callback(hObject, eventdata, handles)
% hObject    handle to edit_RedundancyRadius (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_RedundancyRadius as text
%        str2double(get(hObject,'String')) returns contents of edit_RedundancyRadius as a double


% --- Executes during object creation, after setting all properties.
function edit_RedundancyRadius_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_RedundancyRadius (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
