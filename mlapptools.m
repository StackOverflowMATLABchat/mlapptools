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
        function alignstring(uielement, alignment)
            alignment = lower(alignment);
            mlapptools.validatealignmentstr(alignment)
            mlapptools.togglewarnings('off')

            rez = '';
            while ~strcmp(rez, sprintf('"%s"', alignment))
                try
                    % 1. Get a handle to the webwindow:
                    win = struct(struct(uielement.Parent).Controller).Container.CEF;
                    % 2. Find which element of the DOM we want to edit (as before):
                    data_tag = char(struct(uielement).Controller.ProxyView.PeerNode.getId);
                    % 3. Manipulate the DOM via a JS command
                    JSstr = sprintf('dojo.style(dojo.query("[data-tag^=''%s'']")[0], "textAlign", "%s")', ...
                                  data_tag, alignment);
                    rez = win.executeJS(JSstr);
                catch
                    % TODO: See if an infinite loop condition is possible
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