page 50207 "ETL BC Distances Api"
{
    PageType = API;
    APIPublisher = 'etlpipeline';
    APIGroup = 'warehouse';
    APIVersion = 'v1.0';
    EntityName = 'etlDistance';
    EntitySetName = 'etlDistances';
    SourceTable = "ETL BC Distance";
    DelayedInsert = true;
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = false;
    ODataKeyFields = "Session Id";

    layout
    {
        area(Content)
        {
            field(sessionId;           Rec."Session Id")            { Caption = 'sessionId'; }
            field(sessionDate;         Rec."Session Date")          { Caption = 'sessionDate'; }
            field(totalDistanceKm;     Rec."Total Distance Km")     { Caption = 'totalDistanceKm'; }
            field(totalDistanceMeters; Rec."Total Distance Meters") { Caption = 'totalDistanceMeters'; }
            field(maxSpeedKmh;         Rec."Max Speed Kmh")         { Caption = 'maxSpeedKmh'; }
            field(avgSpeedKmh;         Rec."Avg Speed Kmh")         { Caption = 'avgSpeedKmh'; }
            field(totalActiveSeconds;  Rec."Total Active Seconds")  { Caption = 'totalActiveSeconds'; }
            field(eventCount;          Rec."Event Count")           { Caption = 'eventCount'; }
            field(firstEventAt;        Rec."First Event At")        { Caption = 'firstEventAt'; }
            field(lastEventAt;         Rec."Last Event At")         { Caption = 'lastEventAt'; }
            field(etlLoadedAt;         Rec."ETL Loaded At")         { Caption = 'etlLoadedAt'; }
        }
    }
}
