page 50202 "ETL BC Shipment Line List"
{
    PageType = List;
    Caption = 'Expéditions — Lignes';
    SourceTable = "ETL BC Shipment Line";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Document No"; Rec."Document No") { ApplicationArea = All; }
                field("Line No"; Rec."Line No") { ApplicationArea = All; }
                field("Article Id"; Rec."Article Id") { ApplicationArea = All; }
                field("Quantity"; Rec."Quantity") { ApplicationArea = All; DecimalPlaces = 0:4; }
                field("Location Code"; Rec."Location Code") { ApplicationArea = All; }
                field("ETL Loaded At"; Rec."ETL Loaded At") { ApplicationArea = All; }
            }
        }
    }
}
