<!DOCTYPE html>
<%@ page contentType="text/html; charset=UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core"%>

<c:set var="contextPath" value="${pageContext.request.contextPath}" />
<c:set var="mainPage" value="b_search.jsp" scope="page" />

<%@ page import="org.baraza.DB.BDB" %>
<%@ page import="org.baraza.DB.BQuery" %>
<%@ page import="org.baraza.DB.BTranslations" %>
<%@ page import="org.baraza.utils.BWebUtils" %>
<%@ page import="org.baraza.xml.BElement" %>
<%@ page import="org.baraza.xml.BXML" %>

<%
	ServletContext context = getServletContext();
	String viewKey = request.getParameter("view");
	String viewData = request.getParameter("data");
	
	String jqGridHead = "";
	boolean isGrid = false;
	
	BXML xml = new BXML(context, request, false);
	if((xml.getDocument() != null) && (viewKey != null)){
		BElement root = xml.getRoot();
		BElement view = root.getView(viewKey);
		
		if(view != null) {
			if(view.getName().equals("GRID")) {
				isGrid = true;
				
				BTranslations translations = null;
				if(context.getAttribute("translations") !=  null) 
					translations = (BTranslations) context.getAttribute("translations");
				
				String dbConfig = "java:/comp/env/jdbc/database";
				BDB db = new BDB(dbConfig);
				db.setOrgID(root.getAttribute("org"));
				db.setUser(request.getRemoteAddr(), request.getRemoteUser());
				
				jqGridHead =  BWebUtils.getJSONHeader(view, translations, db.getUser(), viewKey, viewData);
				
				db.close();
			}
		}
	}
	
%>

<html lang="en">
<!--<![endif]-->
<!-- BEGIN HEAD -->
<head>
	<meta charset="utf-8"/>
	<title><%= pageContext.getServletContext().getInitParameter("web_title") %></title>
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<meta content="width=device-width, initial-scale=1" name="viewport"/>
	<meta content="Open Baraza Framework" name="description"/>
	<meta content="Open Baraza" name="author"/>
	
	<!-- BEGIN GLOBAL MANDATORY STYLES -->
	<link href="http://fonts.googleapis.com/css?family=Open+Sans:400,300,600,700&subset=all" rel="stylesheet" type="text/css"/>
	<link href="./assets/global/plugins/font-awesome/css/font-awesome.min.css"  rel="stylesheet" type="text/css"/>
	<link href="./assets/global/plugins/fontawesome-web/css/solid.min.css" rel="stylesheet" type="text/css" />
	<link href="./assets/global/plugins/fontawesome-web/css/all.min.css" rel="stylesheet" type="text/css" />
	<link href="./assets/global/plugins/simple-line-icons/simple-line-icons.min.css" rel="stylesheet" type="text/css"/>
	<link href="./assets/global/plugins/bootstrap/css/bootstrap.min.css" rel="stylesheet" type="text/css"/>
	<link href="./assets/global/plugins/uniform/css/uniform.default.css" rel="stylesheet" type="text/css"/>
	<link href="./assets/global/plugins/bootstrap-switch/css/bootstrap-switch.min.css" rel="stylesheet" type="text/css"/>
	<!-- END GLOBAL MANDATORY STYLES -->

	<link href="./assets/global/plugins/jquery-ui/jquery-ui-1.10.3.custom.min.css" rel="stylesheet" type="text/css" media="screen" />
	<link href="./assets/global/plugins/jquery-multi-select/css/multi-select.css" rel="stylesheet" type="text/css" />
    <link href="./assets/jqgrid/css/ui.jqgrid.css" rel="stylesheet" type="text/css" media="screen" />
    <link type="text/css" rel="stylesheet" href="./assets/admin/layout4/css/custom.css" />
	
</head>
    
<body class="page-header-fixed page-sidebar-closed-hide-logo page-sidebar-closed-hide-logo page-footer-fixed">

	<!-- <div class='table-scrollable page-container'> -->
		<table id='jqlist' class='table table-striped table-bordered table-hover'></table>
		<div id='jqpager'></div>	
	<!-- </div> -->

	<!-- BEGIN CORE PLUGINS -->
	<!--[if lt IE 9]>
	<script src="./assets/global/plugins/respond.min.js"></script>
	<script src="./assets/global/plugins/excanvas.min.js"></script>
	<![endif]-->
	<script src="./assets/global/plugins/jquery.min.js" type="text/javascript"></script>
	<script src="./assets/global/plugins/jquery-migrate.min.js" type="text/javascript"></script>
	<!-- IMPORTANT! Load jquery-ui.min.js before bootstrap.min.js to fix bootstrap tooltip conflict with jquery ui tooltip -->
	<script src="./assets/global/plugins/jquery-ui/jquery-ui.min.js" type="text/javascript"></script>
	<!--<script src="./jquery-ui-1.11.4.custom/jquery-ui.min.js"  type="text/javascript"></script>-->
	<script src="./assets/global/plugins/bootstrap/js/bootstrap.min.js" type="text/javascript"></script>
	<script src="./assets/global/plugins/bootstrap-hover-dropdown/bootstrap-hover-dropdown.min.js" type="text/javascript"></script>
	<script src="./assets/global/plugins/jquery-slimscroll/jquery.slimscroll.min.js" type="text/javascript"></script>
	<script src="./assets/global/plugins/jquery.blockui.min.js" type="text/javascript"></script>
	<script src="./assets/global/plugins/jquery.cokie.min.js" type="text/javascript"></script>
	<script src="./assets/global/plugins/uniform/jquery.uniform.min.js" type="text/javascript"></script>
	<script src="./assets/global/plugins/bootstrap-switch/js/bootstrap-switch.min.js" type="text/javascript"></script>
	<!-- END CORE PLUGINS -->

	<script type="text/javascript" src="./assets/jqgrid/js/i18n/grid.locale-en.js"></script>
	<script type="text/javascript" src="./assets/jqgrid/js/jquery.jqGrid.min.js"></script>


    <% if(isGrid) { %>
	<%@ include file="./assets/include/inc_search.jsp" %>
    <% } %>

</body>
<!-- END BODY -->
</html>



