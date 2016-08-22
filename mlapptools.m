classdef mlapptools
    % MLAPPTOOLS is a class definition
    %
    % MLAPPTOOLS methods:
    
    properties (Constant)
        querytimeout = 5;  % Dojo query timeout period, seconds
    end
    
    methods
        function obj = mlapptools
            % Dummy constructor so we don't return an empty class instance
            clear obj
        end
    end
    
    
    methods (Static)
        function textAlign(uielement, alignment)
            alignment = lower(alignment);
            mlapptools.validatealignmentstr(alignment)
            
            [win, widgetID] = mlapptools.getWebElements(uielement);
            
            alignsetstr = sprintf('dojo.style(dojo.query("#%s")[0], "textAlign", "%s")', widgetID, alignment);
            win.executeJS(alignsetstr);
        end
        
        
        function fontWeight(uielement, weight)
            weight = mlapptools.validatefontweight(weight);
            
            [win, widgetID] = mlapptools.getWebElements(uielement);
            
            fontwtsetstr = sprintf('dojo.style(dojo.query("#%s")[0], "font-weight", "%s")', widgetID, weight);
            win.executeJS(fontwtsetstr);
        end
        
        
        function fontColor(uielement, newcolor)
            newcolor = mlapptools.validateCSScolor(newcolor);

            [win, widgetID] = mlapptools.getWebElements(uielement);
            
            fontwtsetstr = sprintf('dojo.style(dojo.query("#%s")[0], "color", "%s")', widgetID, newcolor);
            win.executeJS(fontwtsetstr);
        end
    end
    
    
    methods (Static, Access = private)
        function [win] = getWebWindow(uifigurewindow)
            % TODO: Check that we've been passed an app designer figure window
            mlapptools.togglewarnings('off')
            
            tic
            while true && (toc < mlapptools.querytimeout)
                try
                    win = struct(struct(uifigurewindow).Controller).Container.CEF;
                    break
                catch err
                    if strcmp(err.identifier, 'MATLAB:nonExistentField')
                        pause(0.01)
                    else
                        mlapptools.togglewarnings('on')
                        rethrow(err)
                    end
                end
            end
            mlapptools.togglewarnings('on')
            
            if toc >= mlapptools.querytimeout
                msgID = 'mlapptools:getWidgetID:QueryTimeout';
                error(msgID, ...
                    'WidgetID query timed out after %u seconds, UI needs more time to load', ...
                    mlapptools.querytimeout);
            end
        end
            
        
        function [data_tag] = getDataTag(uielement)
            mlapptools.togglewarnings('off')
            data_tag = char(struct(uielement).Controller.ProxyView.PeerNode.getId);
            mlapptools.togglewarnings('on')
        end
        
        
        function [widgetID] = getWidgetID(win, data_tag)
            widgetquerystr = sprintf('dojo.getAttr(dojo.query("[data-tag^=''%s''] > div")[0], "widgetid")', data_tag);
            
            tic
            while true && (toc < mlapptools.querytimeout)
                try
                    widgetID = win.executeJS(widgetquerystr);
                    widgetID = widgetID(2:end-1);
                    break
                catch err
                    if ~isempty(strfind(err.message, 'JavaScript error: Uncaught ReferenceError: dojo is not defined')) || ...
                            ~isempty(strfind(err.message, 'Cannot read property ''widgetid'' of null'))
                        pause(0.01)
                    else
                        mlapptools.togglewarnings('on')
                        rethrow(err)
                    end
                end
            end
            mlapptools.togglewarnings('on')
            
            if toc >= mlapptools.querytimeout
                msgID = 'mlapptools:getWidgetID:QueryTimeout';
                error(msgID, ...
                      'WidgetID query timed out after %u seconds, UI needs more time to load', ...
                      mlapptools.querytimeout);
            end
        end
        
        
        function [win, widgetID] = getWebElements(uielement)
            % Get a handle to the webwindow
            win = mlapptools.getWebWindow(uielement.Parent);
            
            % Find which element of the DOM we want to edit
            data_tag = mlapptools.getDataTag(uielement);
            
            % Manipulate the DOM via a JS command
            widgetID = mlapptools.getWidgetID(win, data_tag);
        end
        
        
        function togglewarnings(togglestr)
            switch lower(togglestr)
                case 'on'
                    warning on MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame
                    warning on MATLAB:structOnObject
                case 'off'
                    warning off MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame
                    warning off MATLAB:structOnObject
                otherwise
                    % Do nothing
            end
        end
        
       
        function validatealignmentstr(alignment)
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
        end
        
        
        function [weight] = validatefontweight(weight)
            if ischar(weight)
                weight = lower(weight);
                validstrs = {'normal', 'bold', 'bolder', 'lighter', 'initial'};
                
                if ~any(ismember(weight, validstrs))
                    msgID = 'mlapptools:fontWeight:InvalidFontWeightString';
                    error(msgID, 'Invalid font weight specified: ''%s''', alignment);
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
                % Throw error
            end
        end
        
        
        function [newcolor] = validateCSScolor(newcolor)
        end
    end
end