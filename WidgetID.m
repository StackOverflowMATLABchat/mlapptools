classdef WidgetID < handle
  % A data class for storing identifying information about JS widgets in UIFigures.

  properties (GetAccess = public, SetAccess = public)
    ID_attr char
    ID_val char
  end
  
  methods
    % Counstructor:
    function obj = WidgetID(identifyingAttributeName, identifyingAttributeValue)
      obj.ID_attr = identifyingAttributeName;
      obj.ID_val  = identifyingAttributeValue;
    end    
  end
  
end