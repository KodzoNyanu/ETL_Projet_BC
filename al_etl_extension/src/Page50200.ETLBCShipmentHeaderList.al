page 50200 "ETL BC Shipment Header List"
{
    PageType = List;
    Caption = 'Expéditions — En-têtes';
    SourceTable = "ETL BC Shipment Header";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Headers)
            {
                field("Header Id"; Rec."Header Id") { ApplicationArea = All; }
                field("Customer No"; Rec."Customer No") { ApplicationArea = All; }
                field("Order No"; Rec."Order No") { ApplicationArea = All; }
                field("Shipment Date"; Rec."Shipment Date") { ApplicationArea = All; }
                field("Ship To City"; Rec."Ship To City") { ApplicationArea = All; }
                field("Ship To Country"; Rec."Ship To Country") { ApplicationArea = All; }
                field("ETL Loaded At"; Rec."ETL Loaded At") { ApplicationArea = All; }
            }
        }
    }
}
