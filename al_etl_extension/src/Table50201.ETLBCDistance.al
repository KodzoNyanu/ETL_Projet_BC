table 50201 "ETL BC Distance"
{
    Caption = 'ETL BC Distance';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Session Id"; Text[50])
        {
            Caption = 'Session Id';
            DataClassification = CustomerContent;
        }
        field(2; "Session Date"; Date)
        {
            Caption = 'Session Date';
            DataClassification = CustomerContent;
        }
        field(3; "Total Distance Km"; Decimal)
        {
            Caption = 'Total Distance Km';
            DataClassification = CustomerContent;
        }
        field(4; "Total Distance Meters"; Decimal)
        {
            Caption = 'Total Distance Meters';
            DataClassification = CustomerContent;
        }
        field(5; "Max Speed Kmh"; Decimal)
        {
            Caption = 'Max Speed Kmh';
            DataClassification = CustomerContent;
        }
        field(6; "Avg Speed Kmh"; Decimal)
        {
            Caption = 'Avg Speed Kmh';
            DataClassification = CustomerContent;
        }
        field(7; "Total Active Seconds"; Integer)
        {
            Caption = 'Total Active Seconds';
            DataClassification = CustomerContent;
        }
        field(8; "Event Count"; Integer)
        {
            Caption = 'Event Count';
            DataClassification = CustomerContent;
        }
        field(9; "First Event At"; DateTime)
        {
            Caption = 'First Event At';
            DataClassification = CustomerContent;
        }
        field(10; "Last Event At"; DateTime)
        {
            Caption = 'Last Event At';
            DataClassification = CustomerContent;
        }
        field(11; "ETL Loaded At"; DateTime)
        {
            Caption = 'ETL Loaded At';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Session Id") { Clustered = true; }
        key(ByDate; "Session Date") { }
    }
}
