page 50214 "ETL BC Update Distance API"
{
    PageType = API;
    APIPublisher = 'etlpipeline';
    APIGroup = 'warehouse';
    APIVersion = 'v1.0';
    EntityName = 'etlDistanceUpdate';
    EntitySetName = 'etlDistanceUpdates';
    SourceTable = "ETL BC Distance";
    DelayedInsert = true;
    InsertAllowed = true;
    ModifyAllowed = false;
    DeleteAllowed = false;
    ODataKeyFields = "Session Id";

    layout
    {
        area(Content)
        {
            field(sessionId;       Rec."Session Id")        { Caption = 'sessionId'; }
            field(totalDistanceKm; Rec."Total Distance Km") { Caption = 'totalDistanceKm'; }
            field(etlLoadedAt;     Rec."ETL Loaded At")     { Caption = 'etlLoadedAt'; }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        Mgr: Codeunit "ETL BC Import Manager";
    begin
        Mgr.UpsertDistanceRealtime(Rec."Session Id", Rec."Total Distance Km");
        exit(false);
    end;
}
