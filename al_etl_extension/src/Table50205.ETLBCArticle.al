table 50205 "ETL BC Article"
{
    Caption = 'ETL BC Article';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Article Id"; Code[50])
        {
            Caption = 'Article Id';
            DataClassification = CustomerContent;
        }
        field(2; "Description"; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(3; "Unit Of Measure"; Code[20])
        {
            Caption = 'Unit Of Measure';
            DataClassification = CustomerContent;
        }
        field(4; "Type"; Text[50])
        {
            Caption = 'Type';
            DataClassification = CustomerContent;
        }
        field(5; "Item Category"; Code[20])
        {
            Caption = 'Item Category';
            DataClassification = CustomerContent;
        }
        field(6; "Unit Price"; Decimal)
        {
            Caption = 'Unit Price';
            DataClassification = CustomerContent;
        }
        field(7; "Unit Cost"; Decimal)
        {
            Caption = 'Unit Cost';
            DataClassification = CustomerContent;
        }
        field(8; "Costing Method"; Text[50])
        {
            Caption = 'Costing Method';
            DataClassification = CustomerContent;
        }
        field(9; "ETL Loaded At"; DateTime)
        {
            Caption = 'ETL Loaded At';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Article Id") { Clustered = true; }
    }
}
