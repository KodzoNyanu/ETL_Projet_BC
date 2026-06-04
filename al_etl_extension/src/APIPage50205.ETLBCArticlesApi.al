page 50213 "ETL BC Articles Api"
{
    PageType = API;
    APIPublisher = 'etlpipeline';
    APIGroup = 'warehouse';
    APIVersion = 'v1.0';
    EntityName = 'etlArticle';
    EntitySetName = 'etlArticles';
    SourceTable = "ETL BC Article";
    DelayedInsert = true;
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = false;
    ODataKeyFields = "Article Id";

    layout
    {
        area(Content)
        {
            field(articleId;      Rec."Article Id")       { Caption = 'articleId'; }
            field(description;    Rec."Description")      { Caption = 'description'; }
            field(unitOfMeasure;  Rec."Unit Of Measure")  { Caption = 'unitOfMeasure'; }
            field(type;           Rec."Type")             { Caption = 'type'; }
            field(itemCategory;   Rec."Item Category")    { Caption = 'itemCategory'; }
            field(unitPrice;      Rec."Unit Price")       { Caption = 'unitPrice'; }
            field(unitCost;       Rec."Unit Cost")        { Caption = 'unitCost'; }
            field(costingMethod;  Rec."Costing Method")   { Caption = 'costingMethod'; }
            field(etlLoadedAt;    Rec."ETL Loaded At")    { Caption = 'etlLoadedAt'; }
        }
    }
}
