classdef (Abstract) mlapptools
    % MLAPPTOOLS is a collection of static methods for customizing the 
    % R2016a-introduced web-based uifigure windows and associated UI elements 
    % through DOM manipulations.
    %
    % MLAPPTOOLS' public methods:
    %
    % aboutDojo      - Return the dojo toolkit version.
    % fontColor      - Modify font color.
    % fontWeight     - Modify font weight.
    % getHTML        - Return the full HTML code of a uifigure.
    % getWebElements - Extract a webwindow handle and a widget ID from a uifigure control handle.
    % getWebWindow   - Extract a webwindow handle from a uifigure handle.
    % getWidgetInfo  - Gather information about a specific dijit widget.
    % getWidgetList  - Gather information about all dijit widget in a specified uifigure.
    % setStyle       - Modify a specified style property.
    % setTimeout     - Override the default timeout for dojo commands, for a specific uifigure.
    % textAlign      - Modify text alignment.
    % waitForFigureReady - A blocking method that only returns after the uifigure is fully loaded.
    %
    % See README.md for detailed documentation and examples.
    
    
    properties (Access = private, Constant = true)
        QUERY_TIMEOUT = 5;  % Dojo query timeout period, seconds
        TAG_TIMEOUT = 'QUERY_TIMEOUT';
        DEF_ID_ATTRIBUTE = 'id';
    end
            
    methods (Access = public, Static = true)       
      
        function [dojoVersion] = aboutDojo()
        % A method for getting version info about the Dojo Toolkit visible by MATLAB.
        
            if ~numel(matlab.internal.webwindowmanager.instance.findAllWebwindows())
                f=uifigure; drawnow; tmpWindowCreated = true;              
            else
                tmpWindowCreated = false;
            end

            dojoVersion = matlab.internal.webwindowmanager.instance ...
                                .windowList(1).executeJS('dojo.version');

            if tmpWindowCreated
                delete(f);
            end
            % If MATLAB is sufficiently new, convert the JSON to a struct:  
            if str2double(subsref(ver('matlab'), substruct('.','Version'))) >= 9.1 %R2016b
                dojoVersion = jsondecode(dojoVersion);
            end
        end % aboutDojo
                 
        function fontColor(uiElement, newcolor)
        % A method for manipulating text color.
            newcolor = mlapptools.validateCSScolor(newcolor);

            [win, ID_struct] = mlapptools.getWebElements(uiElement);
            
            mlapptools.setStyle(win, 'color', newcolor, ID_struct);
        end % fontColor
                
        function fontWeight(uiElement, weight)
        % A method for manipulating font weight, which controls how thick or 
        % thin characters in text should be displayed.
            weight = mlapptools.validateFontWeight(weight);     
            
            [win, ID_struct] = mlapptools.getWebElements(uiElement);
            
            mlapptools.setStyle(win, 'font-weight', weight, ID_struct);
        end % fontWeight                                       
                
        function [fullHTML] = getHTML(hUIFig)
        % A method for dumping the HTML code of a uifigure.
        % Intended for R2017b (and onward?) where the CEF url cannot be simply opened in a browser.
                
            win = mlapptools.getWebWindow(hUIFig);            
            % Get the outer html:
            fullHTML = win.executeJS('document.documentElement.outerHTML');
            % Replace some strings for conversion to work well:
            fullHTML = strrep(fullHTML,'%','%%');
            fullHTML = strrep(fullHTML,'><','>\n<');
            % Append the DOCTYPE header and remove quotes:
            fullHTML = sprintf(['<!DOCTYPE HTML>\n' fullHTML(2:end-1)]);
            
        %% Optional things to do with the output:
        % Display as web page:
        %{
            web(['text://' fullHTML]);
        %}
        % Save as file:
        %{
           fid = fopen('uifig_raw.html','w');
           fprintf(fid,'%s',fullHTML);
           fclose(fid);
        %}        
        end % getHTML    
        
        function [win, widgetID] = getWebElements(uiElement)
        % A method for obtaining the webwindow handle and the widget ID corresponding 
        % to the provided uifigure control.
            % Get a handle to the webwindow
            win = mlapptools.getWebWindow(uiElement);
            mlapptools.waitTillWebwindowLoaded(win);
            
            % Find which element of the DOM we want to edit
            switch uiElement.Type
              case 'uitreenode'
                p = uiElement.Parent;
                if ~isa(p,'matlab.ui.container.Tree')
                  p.expand(); % The row must be visible to apply changes
                end
                widgetID = WidgetID('data-test-id', char(struct(uiElement).NodeId));
              otherwise % default:              
                widgetID = mlapptools.getWidgetID(win, mlapptools.getDataTag(uiElement));
            end
        end % getWebElements        
        
        function [win] = getWebWindow(hUIObj)
            warnState = mlapptools.toggleWarnings('off');
            % Make sure we got a valid handle
            % Check to make sure we're addressing the parent figure window,
            % catches the case where the parent is a UIPanel or similar
            hUIFig = ancestor(hUIObj, 'figure');
            
            mlapptools.waitTillFigureLoaded(hUIFig);
            % Since the above checks if a Controller exists, the below should work.
            
            hController = struct(struct(hUIFig).Controller);
            % Check for Controller version:
            switch subsref(ver('matlab'), substruct('.','Version'))
              case {'9.0','9.1'} % R2016a or R2016b
                win = hController.Container.CEF;
              otherwise  % R2017a onward
                win = struct(hController.PlatformHost).CEF;
            end

            warning(warnState); % Restore warning state
            
        end % getWebWindow
        
        function [nfo] = getWidgetInfo(win, widgetID, verboseFlag)
        % A method for gathering information about a specific dijit widget, if its 
        % HTML div id is known.
            %% Handling required positional inputs:
            assert(nargin >= 2,'mlapptools:getWidgetInfo:insufficientInputs',...
              'getWidgetInfo must be called with at least 2 inputs.');
            %% Handling optional inputs:
            if nargin < 3 || isempty(verboseFlag)
              verboseFlag = false;
            end
            %% Querying dijit
            win.executeJS(['var W; require(["dijit/registry"], '...
                 'function(registry){W = registry.byId("' widgetID.ID_val '");}); W = [W];']);          
            % Decoding
            try
              nfo = mlapptools.decodeDijitRegistryResult(win,verboseFlag);
            catch ME
              switch ME.identifier
                case 'mlapptools:decodeDijitRegistryResult:noSuchWidget'
                  warning(ME.identifier, '%s', ME.message);
                otherwise
                  warning('mlapptools:getWidgetInfo:unknownDecodingError',...
                    'Decoding failed for an unexpected reason: %s', ME.message);
              end
              nfo = [];
            end
            % "Clear" the temporary JS variable
            win.executeJS('W = undefined');
        end % getWidgetInfo
        
        function varargout = getWidgetList(hUIFig, verboseFlag)
        % A method for listing all dijit widgets in a uifigure.  
          warnState = mlapptools.toggleWarnings('off');
          %% Handle missing inputs:          
          if nargin < 1 || isempty(hUIFig) || ~mlapptools.isUIFigure(hUIFig)
            throw(MException('mlapptools:getWidgetList:noHandleProvided',...
              'Please provide a valid UIFigure handle as a first input.'));
          end
          warning(warnState); % Restore warning state
          if nargin < 2 || isempty(verboseFlag)
            verboseFlag = false;
          end
          %% Process uifigure:
          win = mlapptools.getWebWindow(hUIFig);  
          % Extract widgets from dijit registry:
          win.executeJS(['var W; require(["dijit/registry"], '...
            ' function(registry){W = registry.toArray();});']); 
          widgets = mlapptools.decodeDijitRegistryResult(win, verboseFlag);
          % "Clear" the temporary JS variable
          win.executeJS('W = undefined');
          %% Assign outputs: 
          varargout{1} = widgets;
          if nargout == 2
            % Convert to a single table:
            varargout{2} = struct2table(mlapptools.unifyStructs(widgets));
          end % getWidgetInfo
        
        end 
                
        function varargout = setStyle(varargin)
        % A method providing an interface for modifying style attributes of uicontrols. 
        %
        % WARNING: Due to the large amount of available style attributes and 
        % corresponding settings, input checking is not performed. As this
        % might lead to unexpected results or errors - USE AT YOUR OWN RISK!
        %
        % "Overloads":
        % 3-parameter call: 
        %   widgetID = setStyle(hControl, styleAttr, styleValue)
        % 4-parameter call: 
        %              setStyle(hWin,     styleAttr, styleValue, ID_obj)    
        
            narginchk(3,4);
            % Unpack inputs:
            styleAttr = varargin{2};
            styleValue = varargin{3};
            
            switch nargin
              case 3
                hControl = varargin{1};
                % Get a handle to the webwindow
                [win, ID_obj] = mlapptools.getWebElements(hControl);
              case 4                
                % By the time we have a WidgetID object, the webwindow handle is available
                win = varargin{1};
                ID_obj = varargin{4};                
            end            
            
            styleSetStr = sprintf('dojo.style(dojo.query("[%s = ''%s'']")[0], "%s", "%s")',...
              ID_obj.ID_attr, ID_obj.ID_val, styleAttr, styleValue);
            % ^ this might result in junk if widgetId=='null'.
            try 
              win.executeJS(styleSetStr);
              % ^ this might crash in case of invalid styleAttr/styleValue.
            catch ME
                % Test for "Invalid or unexpected token":
                ME = mlapptools.checkJavascriptSyntaxError(ME, styleSetStr);
                rethrow(ME);       
            end
            
            % Assign outputs:
            if nargout >= 1
              varargout{1} = ID_obj;
            end
            
        end % setStyle
        
        function setTimeout(hUIFig, newTimeoutInSec)
          % Sets a custom timeout for dojo queries, specified in [s].
          setappdata(hUIFig, mlapptools.TAG_TIMEOUT, newTimeoutInSec);
        end
                
        function textAlign(uiElement, alignment)
        % A method for manipulating text alignment.
            alignment = lower(alignment);
            mlapptools.validateAlignmentStr(alignment)
            
            [win, ID_struct] = mlapptools.getWebElements(uiElement);
            
            mlapptools.setStyle(win, 'textAlign', alignment, ID_struct);
        end % textAlign
        
        function win = waitForFigureReady(hUIFig)
        % This blocking method waits until a UIFigure and its widgets have fully loaded.
            %% Make sure that the handle is valid:
            assert(mlapptools.isUIFigure(hUIFig),...
              'mlapptools:getWebWindow:NotUIFigure',...
              'The provided window handle is not of a UIFigure.');
            assert(strcmp(hUIFig.Visible,'on'),...
              'mlapptools:getWebWindow:FigureNotVisible',...
              'Invisible figures are not supported.');
            %% Wait for the figure to appear:
            mlapptools.waitTillFigureLoaded(hUIFig);
            %% Make sure that Dojo is ready:
            % Get a handle to the webwindow 
            win = mlapptools.getWebWindow(hUIFig);      
            mlapptools.waitTillWebwindowLoaded(win, hUIFig);
        end % waitForFigureReady
        
    end % Public Static Methods
        
    methods (Static = true, Access = private)
                                      
        function ME = checkJavascriptSyntaxError(ME,styleSetStr)        
            if (strcmp(ME.identifier,'cefclient:webwindow:jserror'))                    
                c = strfind(ME.message,'Uncaught SyntaxError:');
                if ~isempty(c)
                  v = str2double(regexp(ME.message(c:end),'-?\d+\.?\d*|-?\d*\.?\d+','match'));
                  msg = ['Syntax error: unexpected token in styleValue: ' styleSetStr(v(1),v(2))];
                  causeException = MException('mlapptools:setStyle:invalidInputs',msg);
                  ME = addCause(ME,causeException);
                end
            end
        end % checkJavascriptSyntaxError
                
        function widgets = decodeDijitRegistryResult(win, verboseFlag)          
          assert(jsondecode(win.executeJS(...
            'this.hasOwnProperty("W") && W !== undefined && W instanceof Array && W.length > 0')),...
            'mlapptools:decodeDijitRegistryResult:noSuchWidget',...
            'The dijit registry doesn''t contain the specified widgetID.');
          
          % Now that we know that W exists, let's try to decode it.
          n = str2double(win.executeJS('W.length;'));
          widgets = cell(n,1);
          % Get the JSON representing the widget, then try to decode, while catching circular references
          for ind1 = 1:n
            try
              widgets{ind1} = jsondecode(win.executeJS(sprintf('W[%d]', ind1-1)));
            catch % handle circular references:
              if verboseFlag
                disp(['Node #' num2str(ind1-1) ' with id ' win.executeJS(sprintf('W[%d].id', ind1-1))...
                  ' could not be fully converted. Attempting fallback...']);
              end
              props = jsondecode(win.executeJS(sprintf('Object.keys(W[%d])', ind1-1)));
              tmp = mlapptools.emptyStructWithFields(props);
              validProps = fieldnames(tmp);
              for indP = 1:numel(validProps)
                try
                  tmp.(validProps{indP}) = jsondecode(win.executeJS(sprintf(['W[%d].' props{indP}], ind1-1)));
                catch
                  % Fallback could be executed recursively for all problematic field 
                  % (to keep the most data), but for now do nothing.
                end
              end
              widgets{ind1} = tmp;
              clear props validProps tmp
            end
          end
        end % decodeDijitRegistryResult
        
        function eStruct = emptyStructWithFields(fields)
        % A convenience method for creating an empty scalar struct with specific field
        % names.
        % INPUTS:
        % fields - cell array of strings representing the required fieldnames.
        
            tmp = [ matlab.lang.makeValidName(fields(:)), cell(numel(fields),1)].';
            eStruct = struct(tmp{:});
        
        end % emptyStructWithFields
                
        function [data_tag] = getDataTag(uiElement)
            warnState = mlapptools.toggleWarnings('off');
            data_tag = char(struct(uiElement).Controller.ProxyView.PeerNode.getId);
            warning(warnState);
        end % getDataTag        

        function hFig = figFromWebwindow(hWebwindow)
          % Using this method is discouraged as it's relatively computation-intensive.
          % Since the figure handle is not a property of the webwindow or its children 
          %   (to our best knowledge), we must list all figures and check which of them
          %   is associated with the input webwindow.
          hFigs = findall(groot, 'Type', 'figure');
          warnState = mlapptools.toggleWarnings('off'); 
          hUIFigs = hFigs(arrayfun(@(x)isstruct(struct(x).ControllerInfo), hFigs));
          hUIFigs = hUIFigs(strcmp({hUIFigs.Visible},'on')); % Hidden figures are ignored
          ww = arrayfun(@mlapptools.getWebWindow, hUIFigs);
          warning(warnState); % Restore warning state
          hFig = hFigs(hWebwindow == ww);          
        end % figFromWebwindow
        
        function [ID_obj] = getWidgetID(win, data_tag)
        % This method returns a structure containing some uniquely-identifying information
        % about a DOM node.
            widgetquerystr = sprintf('dojo.getAttr(dojo.query("[data-tag^=''%s''] > div")[0], "widgetid")', data_tag);
            try % should work for most UI objects
              ID = win.executeJS(widgetquerystr);
              ID_obj = WidgetID(mlapptools.DEF_ID_ATTRIBUTE, ID(2:end-1));
            catch % fallback for problematic objects
              warning('This widget is unsupported.');
%               ID_obj = mlapptools.getWidgetIDFromDijit(win, data_tag);
            end            
        end % getWidgetID
        
        function ID_obj = getWidgetIDFromDijit(win, data_tag)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% EXPERIMENTAL METHOD!!!
          win.executeJS(['var W; require(["dijit/registry"], '...
            'function(registry){W = registry.toArray().map(x => x.domNode.childNodes);});']);
          nWidgets = jsondecode(win.executeJS('W.length'));
          try
            for ind1 = 0:nWidgets-1
              nChild = jsondecode(win.executeJS(sprintf('W[%d].length',ind1)));
              for ind2 = 0:nChild-1
                tmp = win.executeJS(sprintf('W[%d][%d].dataset',ind1,ind2));
                if isempty(tmp)
                  continue
                else
                  tmp = jsondecode(tmp);
                end
                if isfield(tmp,'tag') && strcmp(tmp.tag,data_tag)
                  ID = win.executeJS(sprintf('dojo.getAttr(W[%d][%d].parentNode,"widgetid")',ind1,ind2));
                  error('Bailout!');
                end
              end
            end
            ID_obj = WidgetID('','');
          catch
            % Fix for the case of top-level tree nodes:
            switch tmp.type
              case 'matlab.ui.container.TreeNode'
                tmp = jsondecode(win.executeJS(sprintf(...
                  'dojo.byId(%s).childNodes[0].childNodes[0].childNodes[0].childNodes[%d].dataset',...
                   ID(2:end-1),ind2-1)));
                 ID_obj = WidgetID('data-reactid', tmp.reactid);
            end
          end          
        end % getWidgetIDFromDijit
        
        function to = getTimeout(hFig)
            to = getappdata(hFig, mlapptools.TAG_TIMEOUT);
            if isempty(to), to = mlapptools.QUERY_TIMEOUT; end
        end % getTimeout
        
        function tf = isUIFigure(hList)
            tf = arrayfun(@(x)isa(x,'matlab.ui.Figure') && ...
                              isstruct(struct(x).ControllerInfo), hList);
        end % isUIFigure
                                            
        function oldState = toggleWarnings(togglestr)
            OJF = 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame';
            SOO = 'MATLAB:structOnObject';
            if nargout > 0
                oldState = [warning('query',OJF); warning('query',SOO)];
            end
            switch lower(togglestr)
                case 'on'
                    warning('on',OJF);
                    warning('on',SOO);
                case 'off'
                    warning('off',OJF);
                    warning('off',SOO);
                otherwise
                    % Do nothing
            end
        end % toggleWarnings
               
        function uStruct = unifyStructs(cellOfStructs)
        % A method for merging structs having *some* overlapping field names.
        
            fields = cellfun(@fieldnames, cellOfStructs, 'UniformOutput', false);
            uFields = unique(vertcat(fields{:}));
            sz = numel(cellOfStructs);
            uStruct = repmat(mlapptools.emptyStructWithFields(uFields),sz,1);
            for ind1 = 1:sz
              fields = fieldnames(cellOfStructs{ind1});
              for ind2 = 1:numel(fields)
                uStruct(ind1).(fields{ind2}) = cellOfStructs{ind1}.(fields{ind2});
              end              
            end
        end % unifyStructs        
        
        function validateAlignmentStr(alignment)
            if ~ischar(alignment)
                msgID = 'mlapptools:alignstring:InvalidInputIype';
                error(msgID, 'Expected ''%s'', inputs of type ''%s'' not supported', ...
                      class('Dev-il'), class(alignment));
            end
            
            validstr = {'left', 'right', 'center', 'justify', 'initial'};
            if ~any(ismember(validstr, alignment))
                msgID = 'mlapptools:alignstring:InvalidAlignmentString';
                error(msgID, 'Invalid string alignment specified: ''%s''', alignment);
            end
        end % validateAlignmentStr
                
        function [newcolor] = validateCSScolor(newcolor)
          % TODO
        end % validateCSScolor
                
        function [weight] = validateFontWeight(weight)
            if ischar(weight)
                weight = lower(weight);
                validstrs = {'normal', 'bold', 'bolder', 'lighter', 'initial'};
                
                if ~any(ismember(weight, validstrs))
                    msgID = 'mlapptools:fontWeight:InvalidFontWeightString';
                    error(msgID, 'Invalid font weight specified: ''%s''', weight);
                end
            elseif isnumeric(weight)
                weight = round(weight, -2);
                if weight < 100
                    weight = 100;
                elseif weight > 900
                    weight = 900;
                end
                
                weight = num2str(weight);
            else
                msgID = 'mlapptools:fontWeight:InvalidFontWeight';
                error(msgID, 'Invalid font weight specified: ''%s''', weight);
            end
        end % validateFontWeight
                
        function waitTillFigureLoaded(hFig)
        % A blocking method that ensures a UIFigure has fully loaded.
            warnState = mlapptools.toggleWarnings('off');            
            to = mlapptools.getTimeout(hFig);
            tic
            while (toc < to) && isempty(struct(hFig).Controller)
                pause(0.01)
            end
            if toc > to
                msgID = 'mlapptools:waitTillFigureLoaded:TimeoutReached';
                error(msgID, ...
                      ['Waiting for the figure to load has timed out after %u seconds. ' ...
                      'Try increasing the timeout. If the figure clearly loaded in time, yet '...
                      'this error remains - it might be a bug in the tool! ' ...
                      'Please let the developers know through GitHub.'], ...
                      to);
            end
            warning(warnState);
        end % waitTillFigureLoaded
        
        function waitTillWebwindowLoaded(hWebwindow, hFig)
        % A blocking method that ensures a certain webwindow has fully loaded. 
            if nargin < 2
              hFig = mlapptools.figFromWebwindow(hWebwindow);
            end
            
            to = mlapptools.getTimeout(hFig);
            tic
            while (toc < to) && ~jsondecode(hWebwindow.executeJS(...
                'this.hasOwnProperty("require") && require !== undefined && typeof(require) === "function"'))            
                pause(0.01)
            end
            if toc > to
                msgID = 'mlapptools:waitTillWebwindowLoaded:TimeoutReached';
                error(msgID, ...
                      ['Waiting for the webwindow to load has timed out after %u seconds. ' ...
                      'Try increasing the timeout. If the figure clearly loaded in time, yet '...
                      'this error remains - it might be a bug in the tool! ' ...
                      'Please let the developers know through GitHub.'], ...
                      to);
            else
                hWebwindow.executeJS('require(["dojo/ready"], function(ready){});');
            end
        end % waitTillWebwindowLoaded
                        
    end % Private Static Methods
    
end % classdef

%{
Useful debugging code:

jsprops = sort(jsondecode(win.executeJS('Object.keys(this)')));

%}