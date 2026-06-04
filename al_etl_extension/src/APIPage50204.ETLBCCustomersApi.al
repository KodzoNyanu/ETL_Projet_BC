page 50212 "ETL BC Customers Api"
{
    PageType = API;
    APIPublisher = 'etlpipeline';
    APIGroup = 'warehouse';
    APIVersion = 'v1.0';
    EntityName = 'etlCustomer';
    EntitySetName = 'etlCustomers';
    SourceTable = "ETL BC Customer";
    DelayedInsert = true;
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = false;
    ODataKeyFields = "Customer Id";

    layout
    {
        area(Content)
        {
            field(customerId;      Rec."Customer Id")      { Caption = 'customerId'; }
            field(name;            Rec."Name")             { Caption = 'name'; }
            field(country;         Rec."Country")          { Caption = 'country'; }
            field(postCode;        Rec."Post Code")        { Caption = 'postCode'; }
            field(locationCode;    Rec."Location Code")    { Caption = 'locationCode'; }
            field(currencyCode;    Rec."Currency Code")    { Caption = 'currencyCode'; }
            field(salespersonCode; Rec."Salesperson Code") { Caption = 'salespersonCode'; }
            field(etlLoadedAt;     Rec."ETL Loaded At")    { Caption = 'etlLoadedAt'; }
        }
    }
}
