classdef mlapptools
    % MLAPPTOOLS is a class definition
    %
    % MLAPPTOOLS methods:
    
    properties
        % TODO: Move generic portions of repeated dojo query strings here
        % to reduce copypasta errors as the number of methods expands
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
            mlapptools.togglewarnings('off')

            rez = '';
            while ~strcmp(rez, sprintf('"%s"', alignment))
                try
                    % Get a handle to the webwindow
                    win = struct(struct(uielement.Parent).Controller).Container.CEF;
                    
                    % Find which element of the DOM we want to edit
                    data_tag = char(struct(uielement).Controller.ProxyView.PeerNode.getId);
                    
                    % Manipulate the DOM via a JS command
                    widgetquerystr = sprintf('dojo.getAttr(dojo.query("[data-tag^=''%s''] > div")[0], "widgetid")', data_tag);
                    widgetID = win.executeJS(widgetquerystr);
                    widgetID = widgetID(2:end-1);
                    
                    alignsetstr = sprintf('dojo.style(dojo.query("#%s")[0], "textAlign", "%s")', widgetID, alignment);
                    rez = win.executeJS(alignsetstr);
                catch
                    pause(1); % Give the figure (webpage) some more time to load
                end
            end
            mlapptools.togglewarnings('on')
        end
    end
    
    methods (Static, Access = private)
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