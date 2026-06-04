page 50208 "ETL BC Shipment Lines Api"
{
    PageType = API;
    APIPublisher = 'etlpipeline';
    APIGroup = 'warehouse';
    APIVersion = 'v1.0';
    EntityName = 'etlShipmentLine';
    EntitySetName = 'etlShipmentLines';
    SourceTable = "ETL BC Shipment Line";
    DelayedInsert = true;
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = false;
    ODataKeyFields = "Document No", "Line No";

    layout
    {
        area(Content)
        {
            field(documentNo;   Rec."Document No")   { Caption = 'documentNo'; }
            field(lineNo;       Rec."Line No")        { Caption = 'lineNo'; }
            field(articleId;    Rec."Article Id")     { Caption = 'articleId'; }
            field(quantity;     Rec."Quantity")       { Caption = 'quantity'; }
            field(locationCode; Rec."Location Code") { Caption = 'locationCode'; }
            field(etlLoadedAt;  Rec."ETL Loaded At") { Caption = 'etlLoadedAt'; }
        }
    }
}
