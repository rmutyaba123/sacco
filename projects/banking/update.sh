#!/bin/bash

cp -f ../hr/database/01.common.sql ./database/
cp -f ../hr/database/02.accounts.sql ./database/
cp -f ../hr/database/11.transactions.sql ./database/
cp -f ../hr/database/14.pettycash.sql ./database/
cp -f ../hr/database/16.helpdesk.sql ./database/
cp -f ../hr/database/32.data.sql ./database/

cp -f ../hr/reports/vw_accounts.jasper ./reports/
cp -f ../hr/reports/vw_items.jasper ./reports/
cp -f ../hr/reports/item_category.jasper ./reports/
cp -f ../hr/reports/item_units.jasper ./reports/
cp -f ../hr/reports/vw_ledgerb.jasper ./reports/
cp -f ../hr/reports/vw_ledger.jasper ./reports/
cp -f ../hr/reports/vw_gls.jasper ./reports/
cp -f ../hr/reports/trial_balancec.jasper ./reports/
cp -f ../hr/reports/trial_balanceb.jasper ./reports/
cp -f ../hr/reports/trial_balance.jasper ./reports/
cp -f ../hr/reports/vw_ie.jasper ./reports/
cp -f ../hr/reports/balance_sheet.jasper ./reports/
cp -f ../hr/reports/statement_a.jasper ./reports/
cp -f ../hr/reports/statement.jasper ./reports/
cp -f ../hr/reports/vw_helpdesk.jasper ./reports/
cp -f ../hr/reports/vw_helpdesk_c.jasper ./reports/
cp -f ../hr/reports/vws_tx_ledger.jasper ./reports/
cp -f ../hr/reports/vw_trx.jasper ./reports/
cp -f ../hr/reports/vw_trx_d.jasper ./reports/
cp -f ../hr/reports/vw_trxr.jasper ./reports/
cp -f ../hr/reports/vw_transaction_details.jasper ./reports/
cp -f ../hr/reports/vw_transaction_details_d.jasper ./reports/

