table 50204 "ETL BC Customer"
{
    Caption = 'ETL BC Customer';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Customer Id"; Code[50])
        {
            Caption = 'Customer Id';
            DataClassification = CustomerContent;
        }
        field(2; "Name"; Text[100])
        {
            Caption = 'Name';
            DataClassification = CustomerContent;
        }
        field(3; "Country"; Code[10])
        {
            Caption = 'Country';
            DataClassification = CustomerContent;
        }
        field(4; "Post Code"; Code[20])
        {
            Caption = 'Post Code';
            DataClassification = CustomerContent;
        }
        field(5; "Location Code"; Code[20])
        {
            Caption = 'Location Code';
            DataClassification = CustomerContent;
        }
        field(6; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            DataClassification = CustomerContent;
        }
        field(7; "Salesperson Code"; Code[20])
        {
            Caption = 'Salesperson Code';
            DataClassification = CustomerContent;
        }
        field(8; "ETL Loaded At"; DateTime)
        {
            Caption = 'ETL Loaded At';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Customer Id") { Clustered = true; }
    }
}
