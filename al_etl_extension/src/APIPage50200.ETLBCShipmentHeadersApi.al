page 50206 "ETL BC Shipment Headers Api"
{
    PageType = API;
    APIPublisher = 'etlpipeline';
    APIGroup = 'warehouse';
    APIVersion = 'v1.0';
    EntityName = 'etlShipmentHeader';
    EntitySetName = 'etlShipmentHeaders';
    SourceTable = "ETL BC Shipment Header";
    DelayedInsert = true;
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = false;
    ODataKeyFields = "Header Id";

    layout
    {
        area(Content)
        {
            field(headerId;    Rec."Header Id")      { Caption = 'headerId'; }
            field(customerNo;  Rec."Customer No")    { Caption = 'customerNo'; }
            field(orderNo;     Rec."Order No")        { Caption = 'orderNo'; }
            field(shipmentDate;Rec."Shipment Date")  { Caption = 'shipmentDate'; }
            field(shipToCity;  Rec."Ship To City")   { Caption = 'shipToCity'; }
            field(shipToCountry;Rec."Ship To Country"){ Caption = 'shipToCountry'; }
            field(etlLoadedAt; Rec."ETL Loaded At")  { Caption = 'etlLoadedAt'; }
        }
    }
}
