classdef DOMdemoGUI < matlab.apps.AppBase
 
    % Properties that correspond to app components
    properties (Access = public)
        UIFigure      matlab.ui.Figure           % UI Figure
        LabelTextArea matlab.ui.control.Label    % Text Area
        TextArea      matlab.ui.control.TextArea % This is some text.        
    end
 
    methods (Access = private)
        % Code that executes after component creation
        function startupFcn(app)
        end
    end
 
    % App initialization and construction
    methods (Access = private)
 
        % Create UIFigure and components
        function createComponents(app)
            % Create UIFigure
            app.UIFigure = uifigure;
            app.UIFigure.Position = [100 100 280 102];
            app.UIFigure.Name = 'UI Figure';
            setAutoResize(app, app.UIFigure, true)
 
            % Create LabelTextArea
            app.LabelTextArea = uilabel(app.UIFigure);
            app.LabelTextArea.HorizontalAlignment = 'right';
            app.LabelTextArea.Position = [16 73 62 15];
            app.LabelTextArea.Text = 'Text Area';
 
            % Create TextArea
            app.TextArea = uitextarea(app.UIFigure);
            app.TextArea.Position = [116 14 151 60];
            app.TextArea.Value = {'This is some text.'};
        end
    end
 
    methods (Access = public)
 
        % Construct app
        function app = DOMdemoGUI()
            % Create and configure components
            createComponents(app)
 
            % Register the app with App Designer
            registerApp(app, app.UIFigure)
 
            % Execute the startup function
            runStartupFcn(app, @startupFcn)
 
            if nargout == 0
                clear app
            end
        end
 
        % Code that executes before app deletion
        function delete(app)
            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end