classdef TableDemo < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure  matlab.ui.Figure
        UITable   matlab.ui.control.Table
        Button    matlab.ui.control.Button
    end
    
    properties (Access = private, Constant = true)
        ID_ATTRIBUTE_NAME = 'id';
    end

    methods (Access = private)

        % Button pushed function: Button
        function ButtonPushed(app, ~)
          IAN = app.ID_ATTRIBUTE_NAME;
          hWin = mlapptools.getWebWindow(app.UIFigure);
          % Return all registered widgets:
          [~,w] = mlapptools.getWidgetList(app.UIFigure);
          % Filter list:
          w = w(~cellfun(@isempty,w.id) & ...
                ~cellfun(@isempty,w.visualFamily) & ...
                 cellfun(@(x)~isempty(strfind(x,'uniq')),w.id),:); %#ok<STREMP>
          % Apply random styles:     
          for ind1 = 1:4:size(w,1)
            mlapptools.setStyle(...
            hWin,...
            'border',...
            '2px solid red',...
            WidgetID(IAN,w{ind1,IAN}{1}));
          end
          
          for ind2 = 2:4:size(w,1)
            mlapptools.setStyle(...
            hWin,...
            'background-image',...
            'url(http://lorempixel.com/120/40/)',...
            WidgetID(IAN,w{ind2,IAN}{1}));
          end
          
          for ind3 = 3:4:size(w,1)
            mlapptools.setStyle(...
            hWin,...
            'background-color',...
            ['rgb(' num2str(randi(255)) ',' num2str(randi(255)) ',' ...
                    num2str(randi(255)) +')'],...
            WidgetID(IAN,w{ind3,IAN}{1}));
          end
          
          for ind4 = 4:4:size(w,1)
            mlapptools.setStyle(...
            hWin,...
            'padding',...
            '0cm 1cm 0cm 0cm',...
            WidgetID(IAN,w{ind4,IAN}{1}));
          end                             
          
        end
    end

    % App initialization and construction
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure
            app.UIFigure = uifigure;
            app.UIFigure.Position = [600 600 300 150];
            app.UIFigure.Name = 'UI Figure';
            setAutoResize(app, app.UIFigure, true)

            % Create UITable
            app.UITable = uitable(app.UIFigure);
            app.UITable.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'};
            app.UITable.Data = rand(3);
            app.UITable.RowName = {};
            app.UITable.Position = [25 40 250 100];

            % Create Button
            app.Button = uibutton(app.UIFigure, 'push');
            app.Button.ButtonPushedFcn = createCallbackFcn(app, @ButtonPushed, true);
            app.Button.Position = [90 10 120 25];
            app.Button.Text = 'Modify!';
        end
    end

    methods (Access = public)

        % Construct app
        function app = TableDemo()

            % Create and configure components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

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