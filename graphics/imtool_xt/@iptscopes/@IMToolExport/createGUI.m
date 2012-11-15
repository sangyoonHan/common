function plugInGUI = CreateGUI(this)   %#ok hSrc not used
%CreateGUI Build and cache UI plug-in for IMTool Export plug-in.
%   This adds the button and menu to the scope.
%   No install/render needs to be done here.

%   Copyright 2007-2011 The MathWorks, Inc.
%   $Revision: 1.1.6.6 $  $Date: 2011/08/09 17:55:15 $

% Place=1 for each of these within their respective Export groups
mExport = uimgr.uimenu('IMToolExport',...
    getString(message('images:implayUIString:exportToImageToolMenuLabel')));

mExport.setWidgetPropertyDefault(...
    'busyaction', 'cancel', ...
    'separator', 'on', ...
    'accel',     'e', ...
    'callback',  @(hco, ev) lclExport(this));

% Add the Export to IMTool toolbar button.
bExport = uimgr.uipushtool('IMToolExport');
bExport.IconAppData = 'export_to_imtool';
bExport.setWidgetPropertyDefault(...
    'busyaction',    'cancel', ...
    'interruptible', 'off', ...
    'tooltip', getString(message('images:implayUIString:exportToImageToolTooltip')), ...
    'click', @(hco, ev) lclExport(this));

% Create plug-in installer
plan = {mExport, 'Base/Menus/File/Export'; ...
        bExport, 'Base/Toolbars/Main/Export'};
plugInGUI = uimgr.Installer(plan);

%% ------------------------------------------------------------------------
function lclExport(this)

try
    export(this);
catch ME
    uiscopes.errorHandler(ME.message);
end

% [EOF]
