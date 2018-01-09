classdef WidgetID < handle
  % A data class for storing identifying information about HTML DOM nodes in UIFigures.
  % When the identifying attribute (ID_attr) is "widgetid", this points to a dijit widget.

  properties (GetAccess = public, SetAccess = public)
    ID_attr char
    ID_val char
  end
  
  properties (Access = private, Constant = true)
    DEF_PROP_VAL = '';
  end
  
  methods
    % Counstructor:
    function obj = WidgetID(identifyingAttributeName, identifyingAttributeValue)
      if nargin == 0 % Case of preallocation
        identifyingAttributeName = WidgetID.DEF_PROP_VAL;
        identifyingAttributeValue = WidgetID.DEF_PROP_VAL;
      end
      obj.ID_attr = identifyingAttributeName;
      obj.ID_val  = identifyingAttributeValue;
    end    
  end
  
end