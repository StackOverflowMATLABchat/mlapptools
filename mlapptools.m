classdef mlapptools
    % MLAPPTOOLS is a class definition
    %
    % MLAPPTOOLS methods:
    
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

            rez = '';
            while ~strcmp(rez, sprintf('"%s"', alignment))
                try
                    % Get a handle to the webwindow
                    win = mlapptools.getwebwindow(uielement.Parent);
                    
                    % Find which element of the DOM we want to edit
                    data_tag = mlapptools.getdatatag(uielement);
                    
                    % Manipulate the DOM via a JS command
                    widgetID = mlapptools.getwidgetID(win, data_tag);
                    
                    alignsetstr = sprintf('dojo.style(dojo.query("#%s")[0], "textAlign", "%s")', widgetID, alignment);
                    rez = win.executeJS(alignsetstr);
                catch err
                    % TODO: Check the error so we're not catching errors indiscriminately
                    pause(1); % Give the figure (webpage) some more time to load
                end
            end
            
        end
    end
    
    methods (Static, Access = private)
        function [win] = getwebwindow(uifigurewindow)
            % TODO: Check that we've been passed an app designer figure window
            mlapptools.togglewarnings('off')
            win = struct(struct(uifigurewindow).Controller).Container.CEF;
            mlapptools.togglewarnings('on')
        end
                
        function [data_tag] = getdatatag(uielement)
            mlapptools.togglewarnings('off')
            data_tag = char(struct(uielement).Controller.ProxyView.PeerNode.getId);
            mlapptools.togglewarnings('on')
        end
        
        function [widgetID] = getwidgetID(win, data_tag)
            widgetquerystr = sprintf('dojo.getAttr(dojo.query("[data-tag^=''%s''] > div")[0], "widgetid")', data_tag);
            widgetID = win.executeJS(widgetquerystr);
            widgetID = widgetID(2:end-1);
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
            
            validstr = {'left', 'right', 'center', 'justify'};
            if ~any(ismember(validstr, alignment))
                msgID = 'mlapptools:alignstring:InvalidAlignmentString';
                error(msgID, 'Invalid string alignment specified: ''%s''', alignment);
            end
        end
    end
end