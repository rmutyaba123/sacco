/**
 * @author      Dennis W. Gichangi <dennis@openbaraza.org>
 * @version     2011.0329
 * @since       1.6
 * website		www.openbaraza.org
 * The contents of this file are subject to the GNU Lesser General Public License
 * Version 3.0 ; you may use this file in compliance with the License.
 */
package org.baraza.web;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.Arrays;
import java.util.Map;
import java.util.Enumeration;
import java.util.logging.Logger;

import javax.servlet.ServletContext;
import javax.servlet.http.HttpSession;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.baraza.utils.BWebUtils;
import org.baraza.xml.BXML;
import org.baraza.xml.BElement;
import org.baraza.DB.BDB;
import org.baraza.DB.BJSONQuery;

public class BJSONData extends HttpServlet {
	Logger log = Logger.getLogger(BJSONData.class.getName());
	
	// The search data  has to be ordered alphabetically
	String[] deskTypes = {"ACCORDION", "CROSSTAB", "DIARY", "DIARYEDIT", "FILES", "FILTER", "FORMVIEW", "GRID", "SEARCH", "TABLEVIEW"};

	public void doPost(HttpServletRequest request, HttpServletResponse response)  {
		doGet(request, response);
	}
	
	public void doGet(HttpServletRequest request, HttpServletResponse response) {
	
		String viewKey = request.getParameter("view");
		
		String JSONStr = "";
		if(viewKey == null) JSONStr = getWebJSONData(request);
		else JSONStr = getViewJSONData(request, viewKey);
		
		try {
			PrintWriter out = response.getWriter();
			response.setContentType("application/json;charset=\"utf-8\"");
			
			out.print(JSONStr);
		} catch(IOException ex) {
			System.out.println("ERROR : Cannot get writer from response : " + ex);
		}
	}
	
	public String getWebJSONData(HttpServletRequest request) {
		BWeb web = new BWeb(getServletContext(), request);
		HttpSession webSession = request.getSession(true);
		BElement view = web.getView();
		String viewKey = web.getViewKey();
		String JSONStr = "[]";
		
		if(view == null) return JSONStr;
		if(Arrays.binarySearch(deskTypes, view.getName()) < 0) return JSONStr;

		/*Enumeration e = request.getParameterNames();
        while (e.hasMoreElements()) {
			String ce = (String)e.nextElement();
			System.out.println(ce + ":" + request.getParameter(ce));
		}
		System.out.println("JSONData key : " + viewKey);
		System.out.println(view.toString()); */
		
		String sortSN = "S" + viewKey;
		String sortBy = request.getParameter("sidx");
		if(sortBy != null && sortBy.trim().equals("")) sortBy = null;
		if(sortBy != null) {
			if(sortBy.equals("CL")) sortBy = view.getAttribute("keyfield") + "  " + request.getParameter("sord");
			else sortBy = sortBy + "  " + request.getParameter("sord");
			
			webSession.setAttribute(sortSN, sortBy);
		} else if(webSession.getAttribute(sortSN) != null) {
			sortBy = (String)webSession.getAttribute(sortSN);
		}
//System.out.println("JSON sort : " + sortBy);
		
		Map<String, String> whereParams = web.getWhere(request);
		String whereSql = whereParams.get("wheresql");
		
		String linkData = request.getParameter("linkdata");
		if((view.getAttribute("linkfield") != null) && (linkData != null)){
			if(whereSql == null) whereSql = "(" + view.getAttribute("linkfield") + " = '" + linkData + "')";
			else whereSql += " AND (" + view.getAttribute("linkfield") + " = '" + linkData + "')";
		}
//System.out.println("JSON Where :" + wheresql);

		String pageNum = request.getParameter("page");
		if(pageNum == null) pageNum = "0";
		Integer pageStart = new Integer(0);
		Integer pageSize = new Integer(0);
		try {
			if(request.getParameter("rows") == null) pageSize = new Integer(30);
			else pageSize = new Integer(request.getParameter("rows"));
			pageStart = new Integer(pageNum) * pageSize;
		} catch(NumberFormatException ex) { 
			log.severe("Page size error " + ex);
		}
		
		if(view.getAttribute("superuser", "false").equals("true")) {
			if(!web.getUser().getSuperUser()) return "";
		}
		
		boolean secured = true;
		String rUrl = request.getRequestURI();
		if(rUrl == null) rUrl = "";
		if(rUrl.contains("jsongeneral")) {
			if(!view.getAttribute("secured", "false").equals("true")) secured = false;
			
			String gWhere = request.getParameter("where");
			if(gWhere != null) {
				if(whereSql == null) whereSql = gWhere;
				else whereSql += " AND " + gWhere;
			}
		}
		
		if(secured) {
			BJSONQuery JSONQuery = new BJSONQuery(web.getDB(), view, whereSql, sortBy, pageStart, pageSize);
			JSONStr = JSONQuery.getJSONData(viewKey, false);
			JSONQuery.close();
		}
		
		web.close();
		
		return JSONStr;
	}
	
	public String getViewJSONData(HttpServletRequest request, String viewKey) {
		String JSONStr = "[]";
		
		HttpSession webSession = request.getSession(true);
		
		// Check for well formed viewKey
		if(viewKey == null) return JSONStr;
		String sv[] = viewKey.split(":");
		if(sv.length < 1) return JSONStr;
				
		BXML xml = new BXML(getServletContext(), request, false);
		if(xml.getDocument() != null) {
			BElement root = xml.getRoot();
			BElement elMenu = root.getFirst();
			BElement view = root.getView(viewKey);
//System.out.println("View :" + view.toString());

			if(view == null) return JSONStr;
			if(Arrays.binarySearch(deskTypes, view.getName()) < 0) return JSONStr;
			
			String dbConfig = "java:/comp/env/jdbc/database";
			BDB db = new BDB(dbConfig);
			db.setOrgID(root.getAttribute("org"));
			db.setUser(request.getRemoteAddr(), request.getRemoteUser());
			
			boolean notSecure = false;
			if(db.getUser() == null) {
				if(!view.getAttribute("secured", "false").equals("true")) notSecure = true;
			} else {
				if(db.getUser().checkRole(elMenu, sv[0]) == 2) {
					if(!view.getAttribute("secured", "false").equals("true")) notSecure = true;
				}
			}
			if(notSecure) return JSONStr;
			
			String whereSql = request.getParameter("where");
			String sortBy = request.getParameter("sortby");
			String linkData = request.getParameter("linkdata");
			Integer pageStart = new Integer(0);
			Integer pageSize = new Integer(0);
			
			if(linkData == null) {
				String linkSN = "L" + viewKey;
				if(webSession.getAttribute(linkSN) != null) {
					linkData = (String)webSession.getAttribute(linkSN);
				}
			}
			
			if((view.getAttribute("linkfield") != null) && (linkData != null)){
				if(whereSql == null) whereSql = "(" + view.getAttribute("linkfield") + " = '" + linkData + "')";
				else whereSql += " AND (" + view.getAttribute("linkfield") + " = '" + linkData + "')";
			}
//System.out.println("JSON Where :" + whereSql);

			if(BWebUtils.checkInjection(whereSql)) return JSONStr;
			if(BWebUtils.checkInjection(sortBy)) return JSONStr;
			
			BJSONQuery JSONQuery = new BJSONQuery(db, view, whereSql, sortBy, pageStart, pageSize);
			JSONStr = JSONQuery.getJSONData(viewKey, false);
			JSONQuery.close();
			
			db.close();
		}

		return JSONStr;
	}
}

