page 50203 "ETL BC Ecommerce Line List"
{
    PageType = List;
    Caption = 'Lignes e-commerce';
    SourceTable = "ETL BC Ecommerce Line";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Invoice No"; Rec."Invoice No") { ApplicationArea = All; }
                field("Line No"; Rec."Line No") { ApplicationArea = All; }
                field("Stock Code"; Rec."Stock Code") { ApplicationArea = All; }
                field("Description"; Rec."Description") { ApplicationArea = All; }
                field("Quantity"; Rec."Quantity") { ApplicationArea = All; DecimalPlaces = 0:4; }
                field("Unit Price"; Rec."Unit Price") { ApplicationArea = All; DecimalPlaces = 2:2; }
                field("Total Amount"; Rec."Total Amount") { ApplicationArea = All; DecimalPlaces = 2:2; }
                field("Customer Id"; Rec."Customer Id") { ApplicationArea = All; }
                field("Country"; Rec."Country") { ApplicationArea = All; }
                field("Invoice Date"; Rec."Invoice Date") { ApplicationArea = All; }
                field("ETL Loaded At"; Rec."ETL Loaded At") { ApplicationArea = All; }
            }
        }
    }
}
