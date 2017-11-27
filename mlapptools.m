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
    %
    % See README.md for detailed documentation and examples.
    
    
    properties (Access = private, Constant = true)
        QUERY_TIMEOUT = 5;  % Dojo query timeout period, seconds
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

            [win, widgetID] = mlapptools.getWebElements(uiElement);
            
            fontColorSetStr = sprintf('dojo.style(dojo.query("#%s")[0], "color", "%s")', widgetID, newcolor);
            win.executeJS(fontColorSetStr);
        end % fontColor
                
        function fontWeight(uiElement, weight)
        % A method for manipulating font weight, which controls how thick or 
        % thin characters in text should be displayed.
            weight = mlapptools.validateFontWeight(weight);
            
            [win, widgetID] = mlapptools.getWebElements(uiElement);
            
            fontWeightSetStr = sprintf('dojo.style(dojo.query("#%s")[0], "font-weight", "%s")', widgetID, weight);
            win.executeJS(fontWeightSetStr);
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
        % A method for obtaining the webwindow handle and the widgetID corresponding 
        % to the provided uifigure control.
            % Get a handle to the webwindow
            win = mlapptools.getWebWindow(uiElement.Parent);
            
            % Find which element of the DOM we want to edit
            widgetID = mlapptools.getWidgetID(win, mlapptools.getDataTag(uiElement));
        end % getWebElements        
        
        function [win] = getWebWindow(hUIFig)
            warnState = mlapptools.toggleWarnings('off');
            % Make sure we got a valid handle
            assert(mlapptools.isUIFigure(hUIFig),...
              'mlapptools:getWebWindow:NotUIFigure',...
              'The provided window handle is not of a UIFigure.');
            
            to = mlapptools.getTimeout(hUIFig);
            tic
            while true && (toc < to)
                try
                    hController = struct(struct(hUIFig).Controller);
                    % Check for Controller version:
                    switch subsref(ver('matlab'), substruct('.','Version'))
                      case {'9.0','9.1'} % R2016a or R2016b
                        win = hController.Container.CEF;
                      otherwise  % R2017a onward
                        win = struct(hController.PlatformHost).CEF;
                    end
                    break
                catch err
                    if strcmp(err.identifier, 'MATLAB:nonExistentField')
                        pause(0.01)
                    else
                        warning(warnState); % Restore warning state
                        rethrow(err)
                    end
                end
            end
            warning(warnState); % Restore warning state
            
            if toc >= to
                msgID = 'mlapptools:getWidgetID:QueryTimeout';
                error(msgID, ...
                    'WidgetID query timed out after %u seconds, UI needs more time to load', ...
                    to);
            end
            
        end % getWebWindow
        
        function [nfo] = getWidgetInfo(win, widgetID, verboseFlag)
        % A method for gathering information about a specific dijit widget.
            %% Handling required positional inputs:
            assert(nargin >= 2,'mlapptools:getWidgetInfo:insufficientInputs',...
              'getWidgetInfo must be called with at least 2 inputs.');
            %% Handling optional inputs:
            if nargin < 3 || isempty(verboseFlag)
              verboseFlag = false;
            end
            %% Querying dijit
            win.executeJS(['var W; require(["dijit/registry"], '...
                 'function(registry){W = registry.byId("' widgetID '");}); W = [W];']);          
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
        %              setStyle(hUIFig,   styleAttr, styleValue, widgetID)
        
            % Unpack inputs:
            styleAttr = varargin{2};
            styleValue = varargin{3};
            
            switch nargin
              case 3
                hControl = varargin{1};
                % Get a handle to the webwindow
                [win, widgetID] = mlapptools.getWebElements(hControl);
              case 4                
                hUIFig = varargin{1};
                widgetID = varargin{4};

                % Get a handle to the webwindow  
                win = mlapptools.getWebWindow(hUIFig);
            end
                               
            styleSetStr = sprintf('dojo.style(dojo.query("#%s")[0], "%s", "%s")', widgetID, styleAttr, styleValue);
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
              varargout{1} = widgetID;
            end
            
        end % setStyle
        
        function setTimeout(hUIFig, newTimeoutInSec)
          % Sets a custom timeout for dojo queries, specified in [s].
          setappdata(hUIFig, 'QUERY_TIMEOUT', newTimeoutInSec);
        end
                
        function textAlign(uiElement, alignment)
        % A method for manipulating text alignment.
            alignment = lower(alignment);
            mlapptools.validateAlignmentStr(alignment)
            
            [win, widgetID] = mlapptools.getWebElements(uiElement);
            
            alignSetStr = sprintf('dojo.style(dojo.query("#%s")[0], "textAlign", "%s")', widgetID, alignment);
            win.executeJS(alignSetStr);
        end % textAlign
        
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
              for indP = 1:numel(tmp)
                try
                  tmp.(validProps(indP)) = jsondecode(win.executeJS(sprintf(['W[%d].' props{ind1}], ind1-1)));
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
                                            
        function [widgetID] = getWidgetID(win, data_tag)
            widgetquerystr = sprintf('dojo.getAttr(dojo.query("[data-tag^=''%s''] > div")[0], "widgetid")', data_tag);
            
            to = mlapptools.getTimeout(mlapptools.figFromWebwindow(win));
            tic
            while true && (toc < to)
                try
                    widgetID = win.executeJS(widgetquerystr);
                    widgetID = widgetID(2:end-1);
                    break
                catch err
                    if ~isempty(strfind(err.message, 'JavaScript error: Uncaught ReferenceError: dojo is not defined')) || ...
                       ~isempty(strfind(err.message, 'Cannot read property ''widgetid'' of null'))
                        pause(0.01)
                    else
                        rethrow(err)
                    end
                end
            end
            
            if toc >= to
                msgID = 'mlapptools:getWidgetID:QueryTimeout';
                error(msgID, ...
                      'widgetID query timed out after %u seconds, UI needs more time to load', ...
                      to);
            end
        end % getWidgetID
        
        function to = getTimeout(hFig)
            to = getappdata(hFig,'QUERY_TIMEOUT');
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
        
        function hFig = figFromWebwindow(hWebwindow)
          % Using this method is discouraged.
          hFigs = findall(groot, 'Type', 'figure');
          warnState = mlapptools.toggleWarnings('off'); 
          hUIFigs = hFigs(arrayfun(@(x)isstruct(struct(x).ControllerInfo), hFigs));
          ww = arrayfun(@mlapptools.getWebWindow, hUIFigs);
          warning(warnState); % Restore warning state
          hFig = hFigs(hWebwindow == ww);          
        end % figFromWebwindow
                        
    end % Private Static Methods
    
end % classdef