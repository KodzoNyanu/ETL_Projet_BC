codeunit 50210 "ETL BC Import Manager"
{
    // ─────────────────────────────────────────────────────────────────────────
    //  ETL BC Import Manager
    //  Centralise toute la logique d'import Gold → Business Central.
    //  Appelé par : les API pages (triggers), la page dashboard (actions),
    //               n8n via le webhook distance (WF-04B).
    // ─────────────────────────────────────────────────────────────────────────

    // =========================================================================
    //  SYNC COMPLÈTE — déclenche WF-08 dans n8n (Gold PG → BC)
    // =========================================================================
    procedure TriggerFullSync()
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        JsonBody: Text;
        StatusMsg: Text;
    begin
        JsonBody := '{"source":"bc_manual","triggered_by":"ETL BC Dashboard"}';
        Content.WriteFrom(JsonBody);
        Content.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        Request.SetRequestUri('http://172.18.0.5:5678/webhook/run-gold-to-bc');
        Request.Method := 'POST';
        Request.Content := Content;

        if Client.Send(Request, Response) then begin
            if Response.IsSuccessStatusCode() then
                Message('Synchronisation Gold → BC déclenchée avec succès.')
            else begin
                StatusMsg := Format(Response.HttpStatusCode());
                Error('Erreur lors du déclenchement n8n. Code HTTP : %1', StatusMsg);
            end;
        end else
            Error('Impossible de joindre n8n. Vérifiez que le service est démarré.');
    end;

    // =========================================================================
    //  IMPORT SHIPMENT HEADERS — depuis le JSON reçu par l'API page
    // =========================================================================
    procedure UpsertShipmentHeader(
        HeaderIdVal: Code[50];
        CustomerNoVal: Code[20];
        OrderNoVal: Code[20];
        ShipmentDateVal: Date;
        ShipToCityVal: Text[100];
        ShipToCountryVal: Code[10])
    var
        HeaderRec: Record "ETL BC Shipment Header";
    begin
        if HeaderRec.Get(HeaderIdVal) then begin
            HeaderRec."Customer No"    := CustomerNoVal;
            HeaderRec."Order No"       := OrderNoVal;
            HeaderRec."Shipment Date"  := ShipmentDateVal;
            HeaderRec."Ship To City"   := ShipToCityVal;
            HeaderRec."Ship To Country":= ShipToCountryVal;
            HeaderRec."ETL Loaded At"  := CurrentDateTime();
            HeaderRec.Modify(true);
        end else begin
            HeaderRec."Header Id"      := HeaderIdVal;
            HeaderRec."Customer No"    := CustomerNoVal;
            HeaderRec."Order No"       := OrderNoVal;
            HeaderRec."Shipment Date"  := ShipmentDateVal;
            HeaderRec."Ship To City"   := ShipToCityVal;
            HeaderRec."Ship To Country":= ShipToCountryVal;
            HeaderRec."ETL Loaded At"  := CurrentDateTime();
            HeaderRec.Insert(true);
        end;
    end;

    // =========================================================================
    //  IMPORT DISTANCES GPS — une ligne par session_id
    // =========================================================================
    procedure UpsertDistance(
        SessionIdVal: Text[50];
        SessionDateVal: Date;
        TotalDistKmVal: Decimal;
        TotalDistMetersVal: Decimal;
        MaxSpeedVal: Decimal;
        AvgSpeedVal: Decimal;
        ActiveSecsVal: Integer;
        EventCountVal: Integer;
        FirstEventAtVal: DateTime;
        LastEventAtVal: DateTime)
    var
        DistRec: Record "ETL BC Distance";
    begin
        if DistRec.Get(SessionIdVal) then begin
            DistRec."Session Date"           := SessionDateVal;
            DistRec."Total Distance Km"      := TotalDistKmVal;
            DistRec."Total Distance Meters"  := TotalDistMetersVal;
            DistRec."Max Speed Kmh"          := MaxSpeedVal;
            DistRec."Avg Speed Kmh"          := AvgSpeedVal;
            DistRec."Total Active Seconds"   := ActiveSecsVal;
            DistRec."Event Count"            := EventCountVal;
            DistRec."First Event At"         := FirstEventAtVal;
            DistRec."Last Event At"          := LastEventAtVal;
            DistRec."ETL Loaded At"          := CurrentDateTime();
            DistRec.Modify(true);
        end else begin
            DistRec."Session Id"             := SessionIdVal;
            DistRec."Session Date"           := SessionDateVal;
            DistRec."Total Distance Km"      := TotalDistKmVal;
            DistRec."Total Distance Meters"  := TotalDistMetersVal;
            DistRec."Max Speed Kmh"          := MaxSpeedVal;
            DistRec."Avg Speed Kmh"          := AvgSpeedVal;
            DistRec."Total Active Seconds"   := ActiveSecsVal;
            DistRec."Event Count"            := EventCountVal;
            DistRec."First Event At"         := FirstEventAtVal;
            DistRec."Last Event At"          := LastEventAtVal;
            DistRec."ETL Loaded At"          := CurrentDateTime();
            DistRec.Insert(true);
        end;
    end;

    // =========================================================================
    //  IMPORT SHIPMENT LINES
    // =========================================================================
    procedure UpsertShipmentLine(
        DocumentNoVal: Code[20];
        LineNoVal: Integer;
        ArticleIdVal: Code[50];
        QuantityVal: Decimal;
        LocationCodeVal: Code[10])
    var
        LineRec: Record "ETL BC Shipment Line";
    begin
        if LineRec.Get(DocumentNoVal, LineNoVal) then begin
            LineRec."Article Id"    := ArticleIdVal;
            LineRec."Quantity"      := QuantityVal;
            LineRec."Location Code" := LocationCodeVal;
            LineRec."ETL Loaded At" := CurrentDateTime();
            LineRec.Modify(true);
        end else begin
            LineRec."Document No"   := DocumentNoVal;
            LineRec."Line No"       := LineNoVal;
            LineRec."Article Id"    := ArticleIdVal;
            LineRec."Quantity"      := QuantityVal;
            LineRec."Location Code" := LocationCodeVal;
            LineRec."ETL Loaded At" := CurrentDateTime();
            LineRec.Insert(true);
        end;
    end;

    // =========================================================================
    //  IMPORT ECOMMERCE LINES
    // =========================================================================
    procedure UpsertEcommerceLine(
        InvoiceNoVal: Code[20];
        LineNoVal: Integer;
        StockCodeVal: Code[50];
        DescriptionVal: Text[100];
        QuantityVal: Decimal;
        UnitPriceVal: Decimal;
        TotalAmountVal: Decimal;
        CustomerIdVal: Code[50];
        CountryVal: Code[10];
        InvoiceDateVal: Date)
    var
        EcomRec: Record "ETL BC Ecommerce Line";
    begin
        if EcomRec.Get(InvoiceNoVal, LineNoVal) then begin
            EcomRec."Stock Code"    := StockCodeVal;
            EcomRec."Description"   := DescriptionVal;
            EcomRec."Quantity"      := QuantityVal;
            EcomRec."Unit Price"    := UnitPriceVal;
            EcomRec."Total Amount"  := TotalAmountVal;
            EcomRec."Customer Id"   := CustomerIdVal;
            EcomRec."Country"       := CountryVal;
            EcomRec."Invoice Date"  := InvoiceDateVal;
            EcomRec."ETL Loaded At" := CurrentDateTime();
            EcomRec.Modify(true);
        end else begin
            EcomRec."Invoice No"    := InvoiceNoVal;
            EcomRec."Line No"       := LineNoVal;
            EcomRec."Stock Code"    := StockCodeVal;
            EcomRec."Description"   := DescriptionVal;
            EcomRec."Quantity"      := QuantityVal;
            EcomRec."Unit Price"    := UnitPriceVal;
            EcomRec."Total Amount"  := TotalAmountVal;
            EcomRec."Customer Id"   := CustomerIdVal;
            EcomRec."Country"       := CountryVal;
            EcomRec."Invoice Date"  := InvoiceDateVal;
            EcomRec."ETL Loaded At" := CurrentDateTime();
            EcomRec.Insert(true);
        end;
    end;

    // =========================================================================
    //  IMPORT CUSTOMERS
    // =========================================================================
    procedure UpsertCustomer(
        CustomerIdVal: Code[50];
        NameVal: Text[100];
        CountryVal: Code[10];
        PostCodeVal: Code[20];
        LocationCodeVal: Code[20];
        CurrencyCodeVal: Code[10];
        SalespersonCodeVal: Code[20])
    var
        CustRec: Record "ETL BC Customer";
    begin
        if CustRec.Get(CustomerIdVal) then begin
            CustRec."Name"             := NameVal;
            CustRec."Country"          := CountryVal;
            CustRec."Post Code"        := PostCodeVal;
            CustRec."Location Code"    := LocationCodeVal;
            CustRec."Currency Code"    := CurrencyCodeVal;
            CustRec."Salesperson Code" := SalespersonCodeVal;
            CustRec."ETL Loaded At"    := CurrentDateTime();
            CustRec.Modify(true);
        end else begin
            CustRec."Customer Id"      := CustomerIdVal;
            CustRec."Name"             := NameVal;
            CustRec."Country"          := CountryVal;
            CustRec."Post Code"        := PostCodeVal;
            CustRec."Location Code"    := LocationCodeVal;
            CustRec."Currency Code"    := CurrencyCodeVal;
            CustRec."Salesperson Code" := SalespersonCodeVal;
            CustRec."ETL Loaded At"    := CurrentDateTime();
            CustRec.Insert(true);
        end;
    end;

    // =========================================================================
    //  IMPORT ARTICLES
    // =========================================================================
    procedure UpsertArticle(
        ArticleIdVal: Code[50];
        DescriptionVal: Text[100];
        UOMVal: Code[20];
        TypeVal: Text[50];
        ItemCategoryVal: Code[20];
        UnitPriceVal: Decimal;
        UnitCostVal: Decimal;
        CostingMethodVal: Text[50])
    var
        ArtRec: Record "ETL BC Article";
    begin
        if ArtRec.Get(ArticleIdVal) then begin
            ArtRec."Description"    := DescriptionVal;
            ArtRec."Unit Of Measure":= UOMVal;
            ArtRec."Type"           := TypeVal;
            ArtRec."Item Category"  := ItemCategoryVal;
            ArtRec."Unit Price"     := UnitPriceVal;
            ArtRec."Unit Cost"      := UnitCostVal;
            ArtRec."Costing Method" := CostingMethodVal;
            ArtRec."ETL Loaded At"  := CurrentDateTime();
            ArtRec.Modify(true);
        end else begin
            ArtRec."Article Id"     := ArticleIdVal;
            ArtRec."Description"    := DescriptionVal;
            ArtRec."Unit Of Measure":= UOMVal;
            ArtRec."Type"           := TypeVal;
            ArtRec."Item Category"  := ItemCategoryVal;
            ArtRec."Unit Price"     := UnitPriceVal;
            ArtRec."Unit Cost"      := UnitCostVal;
            ArtRec."Costing Method" := CostingMethodVal;
            ArtRec."ETL Loaded At"  := CurrentDateTime();
            ArtRec.Insert(true);
        end;
    end;

    // =========================================================================
    //  UTILITAIRE — retourne le nombre d'enregistrements par table
    // =========================================================================
    procedure GetRecordCount(TableName: Text[50]) : Integer
    var
        HeaderRec : Record "ETL BC Shipment Header";
        DistRec   : Record "ETL BC Distance";
        LineRec   : Record "ETL BC Shipment Line";
        EcomRec   : Record "ETL BC Ecommerce Line";
        CustRec   : Record "ETL BC Customer";
        ArtRec    : Record "ETL BC Article";
    begin
        case TableName of
            'ShipmentHeaders' : exit(HeaderRec.Count());
            'Distances'       : exit(DistRec.Count());
            'ShipmentLines'   : exit(LineRec.Count());
            'EcommerceLines'  : exit(EcomRec.Count());
            'Customers'       : exit(CustRec.Count());
            'Articles'        : exit(ArtRec.Count());
            else exit(0);
        end;
    end;
}
