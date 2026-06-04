page 50211 "ETL BC Dashboard"
{
    // ─────────────────────────────────────────────────────────────────────────
    //  Tableau de bord ETL — visualisation des 6 tables Gold importées dans BC
    //  Toutes les actions appellent uniquement Codeunit 50210 "ETL BC Import Manager"
    // ─────────────────────────────────────────────────────────────────────────
    PageType = Card;
    Caption = 'ETL — Tableau de Bord Logistique';
    UsageCategory = Lists;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            // ── Statistiques globales ──────────────────────────────────────
            group(Stats)
            {
                Caption = 'État des données Gold importées';

                field(NbShipmentHeaders; GetCount('ShipmentHeaders'))
                {
                    Caption = 'Expéditions (En-têtes)';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                }
                field(NbDistances; GetCount('Distances'))
                {
                    Caption = 'Sessions GPS (Kilométrages)';
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                }
                field(NbShipmentLines; GetCount('ShipmentLines'))
                {
                    Caption = 'Lignes d''expédition';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(NbEcommerceLines; GetCount('EcommerceLines'))
                {
                    Caption = 'Lignes e-commerce';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(NbCustomers; GetCount('Customers'))
                {
                    Caption = 'Clients';
                    ApplicationArea = All;
                    Editable = false;
                }
                field(NbArticles; GetCount('Articles'))
                {
                    Caption = 'Articles';
                    ApplicationArea = All;
                    Editable = false;
                }
            }

            // ── Navigation vers les listes détaillées ─────────────────────
            group(DataAccess)
            {
                Caption = 'Accès aux données';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SyncAll)
            {
                Caption = 'Synchroniser Gold → BC';
                ToolTip = 'Déclenche la synchronisation complète des 6 tables Gold vers Business Central via n8n.';
                ApplicationArea = All;
                Image = Refresh;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    ImportMgr: Codeunit "ETL BC Import Manager";
                begin
                    ImportMgr.TriggerFullSync();
                    CurrPage.Update(false);
                end;
            }

            action(ViewDistances)
            {
                Caption = 'Kilométrages GPS';
                ToolTip = 'Ouvrir la liste complète des sessions GPS.';
                ApplicationArea = All;
                Image = Map;
                RunObject = Page "ETL BC Distance List";
            }

            action(ViewShipmentHeaders)
            {
                Caption = 'Expéditions';
                ToolTip = 'Ouvrir la liste des en-têtes d''expédition.';
                ApplicationArea = All;
                Image = Shipment;
                RunObject = Page "ETL BC Shipment Header List";
            }

            action(ViewShipmentLines)
            {
                Caption = 'Lignes d''expédition';
                ToolTip = 'Ouvrir la liste des lignes d''expédition.';
                ApplicationArea = All;
                Image = AllLines;
                RunObject = Page "ETL BC Shipment Line List";
            }

            action(ViewEcommerceLines)
            {
                Caption = 'Lignes e-commerce';
                ToolTip = 'Ouvrir la liste des lignes e-commerce.';
                ApplicationArea = All;
                Image = OrderList;
                RunObject = Page "ETL BC Ecommerce Line List";
            }

            action(ViewCustomers)
            {
                Caption = 'Clients';
                ToolTip = 'Ouvrir la liste des clients importés.';
                ApplicationArea = All;
                Image = Customer;
                RunObject = Page "ETL BC Customer List";
            }

            action(ViewArticles)
            {
                Caption = 'Articles';
                ToolTip = 'Ouvrir la liste des articles importés.';
                ApplicationArea = All;
                Image = Item;
                RunObject = Page "ETL BC Article List";
            }
        }
    }

    var
        ImportMgrGlobal: Codeunit "ETL BC Import Manager";

    local procedure GetCount(TableName: Text[50]): Integer
    begin
        exit(ImportMgrGlobal.GetRecordCount(TableName));
    end;
}
