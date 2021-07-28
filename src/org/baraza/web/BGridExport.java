/**
 * @author      Dennis W. Gichangi <dennis@openbaraza.org>
 * @version     2011.0329
 * @since       1.6
 * website		www.openbaraza.org
 * The contents of this file are subject to the GNU Lesser General Public License
 * Version 3.0 ; you may use this file in compliance with the License.
 */
package org.baraza.web;

import java.util.Map;
import java.util.HashMap;
import java.io.PrintWriter;
import java.io.OutputStream;
import java.io.IOException;

import javax.servlet.ServletContext;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.ServletOutputStream;

import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.apache.poi.ss.usermodel.CreationHelper;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.DataFormat;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.Font;

import org.baraza.xml.BElement;
import org.baraza.DB.BQuery;
import org.baraza.DB.BCrossTab;

public class BGridExport extends HttpServlet {

	BWeb web = null;

	public void doPost(HttpServletRequest request, HttpServletResponse response)  {
		doGet(request, response);
	}

	public void doGet(HttpServletRequest request, HttpServletResponse response) {
		web = new BWeb(getServletContext(), request);
		
		BElement view = web.getView();
		if(view == null) {
			web.close(); 
			return;
		}
		
		// Call the where create function
		Map<String, String> whereParams = web.getWhere(request);
		String whereSql = whereParams.get("wheresql");

		
		String action = request.getParameter("action");
		if(action == null) action = "export";
		
		try {
			if(action.equals("excel_export")) {
				response.setContentType("application/excel");
				response.addHeader("Content-Disposition", "attachment; filename=ob_report.xlsx");
				
				OutputStream os = response.getOutputStream();
				if(view.getName().equals("GRID") || view.getName().equals("FORMVIEW")) getGridExcel(os, view, whereSql);
				else if (view.getName().equals("CROSSTAB")) getCrossTabExcel(os, view, whereSql);
			} else {
				response.setCharacterEncoding("UTF-8");
				response.setHeader("Cache-Control", "no-cache");
				
				PrintWriter out = response.getWriter();
				out.println(web.getExport(request, response));
			}
		} catch(IOException ex) {
			System.out.println("IO Exception : " + ex);
		}

		web.close(); 
	}
	
	public void getGridExcel(OutputStream os, BElement view, String whereSql) {
		Workbook wb = new XSSFWorkbook();
		CreationHelper createHelper = wb.getCreationHelper();
		Sheet sheet = wb.createSheet(view.getAttribute("name", "report"));
		
		DataFormat format = wb.createDataFormat();
		CellStyle numberStyle = wb.createCellStyle();
		numberStyle.setDataFormat(format.getFormat("#,###.00"));
		CellStyle dateStyle = wb.createCellStyle();
		dateStyle.setDataFormat(createHelper.createDataFormat().getFormat("dd/mm/yyyy"));
		
		CellStyle titleStyle = wb.createCellStyle();
		Font font = wb.createFont();
		font.setBold(true);
		titleStyle.setFont(font); 
		
		Cell cell;
		Row row = sheet.createRow(0);
		int cc = 0;
		for(BElement el : view.getElements()) {
			String colTitle = el.getAttribute("title");
			if(!el.getValue().equals("") && (colTitle != null)) {
				cell = row.createCell(cc);
				cell.setCellValue(colTitle);
				cell.setCellStyle(titleStyle);
				cc++;
			}
		}
		
		boolean cellHide = false;
		String cellStr = null;
		String sRepeat = null;
		Map<String, String> mRepeat = new HashMap<String, String>();
		
		int rc = 0;
		BQuery xlsData = new BQuery(web.getDB(), view, whereSql, null, false);
		xlsData.beforeFirst();
		while(xlsData.moveNext()) {
			cc = 0;
			rc++;
			row = sheet.createRow(rc);
			for(BElement el : view.getElements()) {
				String colName = el.getValue();
				if(!colName.equals("") && (el.getAttribute("title") != null)) {
					cellHide = false;
					if(el.getAttribute("hide.repeat", "false").equals("true")) {
						 sRepeat = mRepeat.get(colName);
						 cellStr = xlsData.getString(colName);
						 if(sRepeat != null) {
							if(sRepeat.equals(cellStr)) cellHide = true;
						 }
						 mRepeat.put(colName, cellStr);
					}
					
					if(cellHide) {
						cell = row.createCell(cc);
						cell.setCellValue("");
					} else if(el.getName().equals("TEXTDECIMAL")) {
						cell = row.createCell(cc);
						cell.setCellValue(xlsData.getFloat(el.getValue()));
						cell.setCellStyle(numberStyle);
					} else if(el.getName().equals("TEXTDATE")) {
						cell = row.createCell(cc);
						cell.setCellValue(xlsData.getDate(el.getValue()));
						cell.setCellStyle(dateStyle);
					} else {
						cell = row.createCell(cc);
						cell.setCellValue(xlsData.formatData(el));
					}
					
					cc++;
				}
			}
		}
		xlsData.close();
		
		cc = 0;
		for(BElement el : view.getElements()) {
			String colTitle = el.getAttribute("title");
			if(!el.getValue().equals("") && (colTitle != null)) {
				sheet.autoSizeColumn(cc);
				cc++;
			}
		}
		
		try {
			wb.write(os);
			os.flush();
		} catch(IOException ex) {
			System.out.println("IO Excel export error : " + ex);
		}
	}
	
	public void getCrossTabExcel(OutputStream os, BElement view, String whereSql) {
		Workbook wb = new XSSFWorkbook();
		CreationHelper createHelper = wb.getCreationHelper();
		Sheet sheet = wb.createSheet(view.getAttribute("name", "report"));
		
		DataFormat format = wb.createDataFormat();
		CellStyle numberStyle = wb.createCellStyle();
		numberStyle.setDataFormat(format.getFormat("#,###.00"));
		CellStyle dateStyle = wb.createCellStyle();
		dateStyle.setDataFormat(createHelper.createDataFormat().getFormat("dd/mm/yyyy"));
		
		CellStyle titleStyle = wb.createCellStyle();
		Font font = wb.createFont();
		font.setBold(true);
		titleStyle.setFont(font);
		
		Map<String, CellStyle> mCellStyles = new HashMap<String, CellStyle>();
		mCellStyles.put("numberStyle", numberStyle);
		mCellStyles.put("dateStyle", dateStyle);
		mCellStyles.put("titleStyle", titleStyle);
		
		Cell cell;
		Row row = sheet.createRow(0);
		int cc = 0;
		
		BCrossTab ct = new BCrossTab(web.getDB(), view, whereSql, null);
		ct.getExcel(sheet, mCellStyles);
		ct.close();
		
		cc = 0;
		for(BElement el : view.getElements()) {
			String colTitle = el.getAttribute("title");
			if(!el.getValue().equals("") && (colTitle != null)) {
				sheet.autoSizeColumn(cc);
				cc++;
			}
		}
		
		try {
			wb.write(os);
			os.flush();
		} catch(IOException ex) {
			System.out.println("IO Excel export error : " + ex);
		}
	}
}

