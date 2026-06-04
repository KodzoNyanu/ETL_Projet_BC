page 50205 "ETL BC Article List"
{
    PageType = List;
    Caption = 'Articles importés';
    SourceTable = "ETL BC Article";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Articles)
            {
                field("Article Id"; Rec."Article Id") { ApplicationArea = All; }
                field("Description"; Rec."Description") { ApplicationArea = All; }
                field("Unit Of Measure"; Rec."Unit Of Measure") { ApplicationArea = All; }
                field("Type"; Rec."Type") { ApplicationArea = All; }
                field("Item Category"; Rec."Item Category") { ApplicationArea = All; }
                field("Unit Price"; Rec."Unit Price") { ApplicationArea = All; DecimalPlaces = 2:4; }
                field("Unit Cost"; Rec."Unit Cost") { ApplicationArea = All; DecimalPlaces = 2:4; }
                field("Costing Method"; Rec."Costing Method") { ApplicationArea = All; }
                field("ETL Loaded At"; Rec."ETL Loaded At") { ApplicationArea = All; }
            }
        }
    }
}
