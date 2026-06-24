page 50201 "ETL BC Distance List"
{
    PageType = List;
    Caption = 'Kilométrages GPS — Sessions temps réel';
    SourceTable = "ETL BC Distance";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Sessions)
            {
                field("Session Id"; Rec."Session Id") { ApplicationArea = All; }
                field("Real Session Date"; Rec."Real Session Date") { ApplicationArea = All; }
                field("Session Date"; Rec."Session Date") { ApplicationArea = All; }
                field("Total Distance Km"; Rec."Total Distance Km")
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0:4;
                }
                field("Max Speed Kmh"; Rec."Max Speed Kmh")
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0:1;
                }
                field("Avg Speed Kmh"; Rec."Avg Speed Kmh")
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0:1;
                }
                field("Total Active Seconds"; Rec."Total Active Seconds") { ApplicationArea = All; }
                field("Event Count"; Rec."Event Count") { ApplicationArea = All; }
                field("First Event At"; Rec."First Event At") { ApplicationArea = All; }
                field("Last Event At"; Rec."Last Event At") { ApplicationArea = All; }
                field("ETL Loaded At"; Rec."ETL Loaded At") { ApplicationArea = All; }
            }
        }
    }
}
