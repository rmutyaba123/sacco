<!DOCTYPE html>
<%@ page contentType="text/html; charset=UTF-8" %>
    <%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core"%>
        <c:set var="contextPath" value="${pageContext.request.contextPath}" />
        <c:set var="mainPage" value="index.jsp" scope="page" />
        <%@ page import="java.util.List" %>
            <%@ page import="java.util.ArrayList" %>
                <%@ page import="org.baraza.DB.BQuery" %>
                    <%@ page import="org.baraza.web.BWeb" %>
                        <%@ page import="org.baraza.xml.BElement" %>

                            <%
	ServletContext context = getServletContext();
	String dbConfig = "java:/comp/env/jdbc/database";
	String xmlcnf = (String)session.getAttribute("xmlcnf");

	String ps = System.getProperty("file.separator");
	String xmlfile = context.getRealPath("WEB-INF") + ps + "configs" + ps + xmlcnf;
	String reportPath = context.getRealPath("reports") + ps;
	String projectDir = context.getInitParameter("projectDir");
	if(projectDir != null) xmlfile = projectDir + ps + "configs" + ps + xmlcnf;

	BWeb web = new BWeb(dbConfig, xmlfile, context);
	web.init(request);
	web.setMainPage(String.valueOf(pageContext.getAttribute("mainPage")));

	String webLogos = web.getWebLogos();
	String logoHeader = "./assets/logos" + webLogos + "/logo_header.png";
%>

                                <!-- Author: Eric Kariuki -->
                                <html lang="en">
                                <!-- begin::Head -->

                                <head>
                                    <meta charset="utf-8" />

                                    <title>Resume Builder</title>
                                    <meta name="description" content="Resume Builder">
                                    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, shrink-to-fit=no">
                                    <meta content="Open Baraza" name="author" />

                                    <!-- BEGIN GLOBAL MANDATORY STYLES -->
                                    <link href="http://fonts.googleapis.com/css?family=Open+Sans:400,300,600,700&subset=all" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/font-awesome/css/font-awesome.min.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/fontawesome-web/css/solid.min.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/fontawesome-web/css/all.min.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/simple-line-icons/simple-line-icons.min.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/bootstrap/css/bootstrap.min.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/uniform/css/uniform.default.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/bootstrap-switch/css/bootstrap-switch.min.css" rel="stylesheet" type="text/css" />
                                    <!-- END GLOBAL MANDATORY STYLES -->
                                    <!-- BEGIN PAGE LEVEL PLUGIN STYLES -->
                                    <link href="./assets/global/plugins/bootstrap-daterangepicker/daterangepicker-bs3.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/fullcalendar/fullcalendar.min.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/jqvmap/jqvmap/jqvmap.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/morris/morris.css" rel="stylesheet" type="text/css">
                                    <!-- END PAGE LEVEL PLUGIN STYLES -->
                                    <!-- BEGIN PAGE STYLES -->
                                    <link href="./assets/admin/pages/css/tasks.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/clockface/css/clockface.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/bootstrap-datepicker/css/bootstrap-datepicker3.min.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/bootstrap-timepicker/css/bootstrap-timepicker.min.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/bootstrap-colorpicker/css/colorpicker.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/bootstrap-daterangepicker/daterangepicker-bs3.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/bootstrap-datetimepicker/css/bootstrap-datetimepicker.min.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/jquery-tags-input/jquery.tagsinput.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/select2/select2.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/jquery-multi-select/css/multi-select.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/bootstrap-toastr/toastr.min.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/global/plugins/bootstrap-fileinput/bootstrap-fileinput.css" rel="stylesheet" type="text/css" />
                                    <link href="./assets/admin/pages/css/profile.css" rel="stylesheet" type="text/css" />

                                    <link href="./assets/global/plugins/jstree/dist/themes/default/style.min.css" rel="stylesheet" type="text/css" />

                                    <!-- CSS to style the file input field as button and adjust the Bootstrap progress bars -->
                                    <link href="./assets/global/plugins/jquery-file-upload/css/jquery.fileupload.css" rel="stylesheet">

                                    <!-- END PAGE STYLES -->
                                    <!-- BEGIN THEME STYLES -->
                                    <!-- DOC: To use 'rounded corners' style just load 'components-rounded.css' stylesheet instead of 'components.css' in the below style tag -->

                                    <% if(web.isMaterial()) { %>
                                        <script>
                                            console.info("Material Design")
                                        </script>
                                        <link href="./assets/global/css/components-md.css" id="style_components" rel="stylesheet" type="text/css" />
                                        <link href="./assets/global/css/plugins-md.css" rel="stylesheet" type="text/css" />

                                        <% } else { %>
                                            <script>
                                                console.info("Default Design")
                                            </script>
                                            <link href="./assets/global/css/components-rounded.css" id="style_components" rel="stylesheet" type="text/css" />
                                            <link href="./assets/global/css/plugins.css" rel="stylesheet" type="text/css" />
                                            <% } %>


                                                <link href="./assets/admin/layout4/css/layout.css" rel="stylesheet" type="text/css" />
                                                <link href="./assets/admin/layout4/css/themes/light.css" rel="stylesheet" type="text/css" id="style_color" />

                                                <!-- END THEME STYLES -->
                                                <link rel="shortcut icon" href="./assets/logos/favicon.png" />

                                                <link href="./assets/global/plugins/jquery-ui/jquery-ui-1.10.3.custom.min.css" rel="stylesheet" type="text/css" media="screen" />
                                                <link href="./assets/jqgrid/css/ui.jqgrid.css" rel="stylesheet" type="text/css" media="screen" />

                                                <!-- jsgrid css -->
                                                <link type="text/css" rel="stylesheet" href="./assets/jsgrid/jsgrid.min.css" />
                                                <link type="text/css" rel="stylesheet" href="./assets/jsgrid/jsgrid-theme.min.css" />



                                                <!-- tabulator css -->
                                                <link type="text/css" rel="stylesheet" href="./assets/tabulator/css/tabulator.min.css">
                                                <link type="text/css" rel="stylesheet" href="./assets/tabulator/css/tabulator_custom.css">

                                                <link type="text/css" rel="stylesheet" href="./assets/admin/layout4/css/custom.css" />

                                                <!--begin::Global Theme Styles -->
                                                <link href="assets/canvas/vendor/vendors.bundle.css" rel="stylesheet" type="text/css" />
                                                <link href="assets/resume/vendor/style.bundle.css" rel="stylesheet" type="text/css" />
                                                <!-- <link href="assets/canvas/css/custom.css" rel="stylesheet" type="text/css" /> -->
                                                <!--end::Global Theme Styles -->



                                                <style type="text/css">
                                                    .hidden {
                                                        display: none;
                                                    }
                                                    
                                                    .fade {
                                                        opacity: 1;
                                                    }
                                                </style>

                                </head>
                                <!-- end::Head -->


                                <!-- begin::Body -->

                                <body class="m-page--fluid m--skin- m-content--skin-light2 m-header--fixed m-header--fixed-mobile m-aside-left--enabled m-aside-left--skin-light m-aside-left--fixed m-aside-left--offcanvas m-footer--push m-aside--offcanvas-default">

                                    <!-- begin:: Page -->
                                    <div class="m-grid m-grid--hor m-grid--root m-page">


                                        <!-- BEGIN HEADER -->
                                        <div class="page-header navbar navbar-fixed-top">
                                            <!-- BEGIN HEADER INNER -->
                                            <div class="page-header-inner" style="width: 100%;">
                                                <!-- BEGIN LOGO -->
                                                <div class="page-logo">
                                                    <a href="index.jsp">
			<img src="<%=logoHeader%>" alt="logo" style="margin: 20px 10px 0 10px; width: 107px;" class="logo-default"/>
			</a>
                                                    <div class="menu-toggler sidebar-toggler">
                                                        <!-- DOC: Remove the above "hide" to enable the sidebar toggler button on header -->
                                                    </div>
                                                </div>
                                                <!-- END LOGO -->
                                                <!-- BEGIN RESPONSIVE MENU TOGGLER -->
                                                <a href="javascript:;" class="menu-toggler responsive-toggler" data-toggle="collapse" data-target=".navbar-collapse">
                                                </a>
                                                <!-- END RESPONSIVE MENU TOGGLER -->

                                                <!-- BEGIN PAGE TOP -->
                                                <div class="page-top">

                                                    <!-- BEGIN TOP NAVIGATION MENU -->
                                                    <div class="top-menu">
                                                        <ul class="nav navbar-nav pull-right">
                                                            <!-- BEGIN USER LOGIN DROPDOWN -->
                                                            <!-- DOC: Apply "dropdown-dark" class after below "dropdown-extended" to change the dropdown styte -->
                                                            <li class="dropdown dropdown-user dropdown-dark">
                                                                <a href="javascript:;" class="dropdown-toggle" data-toggle="dropdown" data-hover="dropdown" data-close-others="true">
                                                                    <span class="username username-hide-on-mobile">
						<%= web.getOrgName() %> | <%= web.getEntityName() %>  </span>
                                                                    <!-- DOC: Do not remove below empty space(&nbsp;) as its purposely used -->
                                                                    <img alt="" class="img-circle" src="./assets/admin/layout4/img/avatar.png" />
                                                                </a>
                                                                <ul class="dropdown-menu dropdown-menu-default">
                                                                    <li class="divider"></li>
                                                                    <li>
                                                                        <a href="logout.jsp?logoff=yes">
                                                                            <i class="icon-key"></i> Log Out </a>
                                                                    </li>
                                                                </ul>
                                                            </li>
                                                            <!-- END USER LOGIN DROPDOWN -->
                                                        </ul>
                                                    </div>
                                                    <!-- END TOP NAVIGATION MENU -->
                                                </div>
                                                <!-- END PAGE TOP -->
                                            </div>
                                            <!-- END HEADER INNER -->
                                        </div>

                                        <!-- END HEADER -->

                                        <!-- begin::Body -->
                                        <section>
                                            <div class="m-grid__item m-grid__item--fluid m-grid m-grid--ver-desktop m-grid--desktop m-body">

                                                <!-- BEGIN: Left Aside -->
                                                <!-- END: Left Aside -->

                                                <div class="m-grid__item m-grid__item--fluid m-wrapper mb-0">

                                                    <div class="m-content pt-5 mt-5">
                                                        <div class="row">
                                                            <div class="m-portlet m-portlet--head-sm m-portlet--light m-portlet--head-solid-bg col-lg-6 mb-0">

                                                                <div class="m-portlet__head">
                                                                    <div class="m-portlet__head-wrapper">
                                                                        <div class="m-portlet__head-caption">
                                                                            <div class="m-portlet__head-title">
                                                                                <h3 class="m-portlet__head-text" id="progressText">0% profile completeness</h3>
                                                                            </div>
                                                                        </div>
                                                                    </div>
                                                                </div>

                                                                <div class="m-portlet__head-progress mx-4">
                                                                    <div class="progress m-progress--sm">
                                                                        <div class="progress-bar" id="progressBar" role="progressbar" aria-valuemin="0" aria-valuemax="100"></div>
                                                                    </div>
                                                                </div>
                                                                <div class="m--space-10"></div>

                                                                <div class="m-portlet__body m-scrollable m-scroller ps ps--active-y" data-scrollbar-shown="true" data-scrollable="true" style="overflow:hidden; height: 105vh">
                                                                    <!--begin::Portlet-->
                                                                    <div class="m-portlet m-portlet--brand m-portlet--head-solid-bg m-portlet--bordered m-portlet--head-sm m-portlet--collapsed" m-portlet="true" id="m_portlet_tools_5">
                                                                        <div class="m-portlet__head">
                                                                            <div class="m-portlet__head-caption">
                                                                                <div class="m-portlet__head-title">
                                                                                    <h3 class="m-portlet__head-text">
                                                                                        Personal Details
                                                                                    </h3>
                                                                                </div>
                                                                            </div>
                                                                            <div class="m-portlet__head-tools">
                                                                                <ul class="m-portlet__nav">
                                                                                    <li class="m-portlet__nav-item">
                                                                                        <a href="" m-portlet-tool="toggle" class="m-portlet__nav-link m-portlet__nav-link--icon"><i class="la la-angle-down"></i></a>
                                                                                    </li>
                                                                                </ul>
                                                                            </div>
                                                                        </div>
                                                                        <!--begin::Form-->
                                                                        <form class="m-form m-form--fit m-form--label-align-right" id="detailsForm" name="personalDetails">
                                                                            <div class="m-portlet__body">
                                                                                <div class="form-group m-form__group row">
                                                                                    <div class="col-lg-6 m-form__group-sub">
                                                                                        <label class="form-control-label" data-name="title">* Title:</label>
                                                                                        <select name="title" class="form-control m-input" required="true">
										<option value="" selected="selected">Select</option>
										<option value="Mr">Mr</option>
										<option value="Miss">Miss</option>
										<option value="Mrs">Mrs</option>
										<option value="Dr">Dr</option>
										<option value="Prof">Prof</option>
									</select>
                                                                                    </div>
                                                                                    <div class="col-lg-6 m-form__group-sub">
                                                                                        <label class="form-control-label" data-name="surname">* Surname:</label>
                                                                                        <input type="text" name="surname" id="surname" class="form-control m-input" placeholder="" required="true">
                                                                                    </div>
                                                                                </div>

                                                                                <div class="form-group m-form__group row">
                                                                                    <div class="col-lg-6 m-form__group-sub">
                                                                                        <label class="form-control-label" data-name="othername">* Other Names:</label>
                                                                                        <input type="text" name="othername" class="form-control m-input" placeholder="" required="true">
                                                                                    </div>
                                                                                    <div class="col-lg-6 m-form__group-sub">
                                                                                        <label class="form-control-label" data-name="email">* Email:</label>
                                                                                        <div class="input-group">
                                                                                            <div class="input-group-prepend"><span class="input-group-text">@</span></div>
                                                                                            <input type="text" name="email" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                    </div>
                                                                                </div>

                                                                                <div class="form-group m-form__group row">
                                                                                    <div class="col-lg-6 m-form__group-sub">
                                                                                        <label class="form-control-label" data-name="phone">* Phone</label>
                                                                                        <div class="input-group">
                                                                                            <div class="input-group-prepend"><span class="input-group-text"><i class="la la-phone"></i></span></div>
                                                                                            <input type="text" name="phone" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="col-lg-6 m-form__group-sub">
                                                                                        <label class="form-control-label" data-name="dob">* Date of Birth</label>
                                                                                        <input type="date" name="dob" class="form-control m-input" placeholder="" required="true">
                                                                                    </div>
                                                                                </div>

                                                                                <div class="form-group m-form__group row">
                                                                                    <div class="col-lg-6 m-form__group-sub">
                                                                                        <label class="form-control-label" data-name="gender">* Gender</label>
                                                                                        <select name="gender" class="form-control m-input" required="true">
									<option value="" selected="selected">Select</option>
									<option value="M">Male</option>
									<option value="F">Female</option>
								</select>
                                                                                    </div>

                                                                                    <div class="col-lg-6 m-form__group-sub">
                                                                                        <label class="form-control-label" data-name="marital-status">* Marital Status</label>
                                                                                        <select name="marital-status" class="form-control m-input" required="true">
									<option value="" selected="selected">Select</option>
									<option value="M">Married</option>
									<option value="S">Single</option>
								</select>
                                                                                    </div>
                                                                                </div>

                                                                                <div class="form-group m-form__group row">
                                                                                    <div class="col-lg-6 m-form__group-sub">
                                                                                        <label class="form-control-label" data-name="nationality">* Nationality</label>
                                                                                        <select name="nationality" class="form-control m-input" required="true">
									<option value="" selected="selected">Select</option>
									<option value="KE">Kenya</option>
								</select>
                                                                                    </div>
                                                                                    <div class="col-lg-6 m-form__group-sub">
                                                                                        <label class="form-control-label" data-name="id-number">* ID Number</label>
                                                                                        <input type="text" name="id-number" class="form-control m-input" placeholder="" required="true">
                                                                                    </div>
                                                                                </div>


                                                                                <div class="form-group m-form__group row">
                                                                                    <div class="col-lg-6 m-form__group-sub">
                                                                                        <label class="form-control-label">Language</label>
                                                                                        <input type="text" name="language" class="form-control m-input" placeholder="">
                                                                                    </div>
                                                                                    <div class="col-lg-6 m-form__group-sub">
                                                                                        <label class="form-control-label">Currency</label>
                                                                                        <select name="currency" class="form-control m-input">
									<option value="1" selected="selected">Kenyan Shilling</option>
									<option value="3">British Pound</option>
									<option value="2">US Dollar</option>
									<option value="4">Euro</option>
								</select>
                                                                                    </div>
                                                                                </div>
                                                                            </div>
                                                                            <div class="m-portlet__foot m-portlet__foot--fit">
                                                                                <div class="m-form__actions m--align-right py-3">
                                                                                    <button type="button" class="btn btn-brand" id="saveProfile">Update</button>
                                                                                </div>
                                                                            </div>
                                                                        </form>
                                                                        <!--end::Form-->
                                                                    </div>
                                                                    <!--end::Portlet-->

                                                                    <!--begin::Portlet-->
                                                                    <div class="m-portlet m-portlet--brand m-portlet--head-solid-bg m-portlet--bordered m-portlet--head-sm" m-portlet="true">
                                                                        <div class="m-portlet__head">
                                                                            <div class="m-portlet__head-caption">
                                                                                <div class="m-portlet__head-title">
                                                                                    <h3 class="m-portlet__head-text">
                                                                                        Address
                                                                                    </h3>
                                                                                </div>
                                                                            </div>
                                                                            <div class="m-portlet__head-tools">
                                                                                <ul class="m-portlet__nav">
                                                                                    <li class="m-portlet__nav-item">
                                                                                        <a href="" class="btn m-btn--pill m-btn--icon m-btn--icon-only m-btn--air btn-brand m-btn modal-toggle" data-toggle="modal" data-target="#addressModal"><i class="la la-plus"></i></a>
                                                                                    </li>
                                                                                </ul>
                                                                            </div>
                                                                        </div>
                                                                        <div class="m-portlet__body py-0">
                                                                            <div class="tab-content">
                                                                                <div class="tab-pane active">
                                                                                    <div class="m-widget4 m-widget4--progress" id="addressContainer">
                                                                                        <div class="m-widget4__item">
                                                                                            No items.
                                                                                        </div>
                                                                                    </div>
                                                                                </div>
                                                                            </div>
                                                                        </div>
                                                                    </div>
                                                                    <!--end::Portlet-->

                                                                    <!--begin::Portlet-->
                                                                    <div class="m-portlet m-portlet--brand m-portlet--head-solid-bg m-portlet--bordered m-portlet--head-sm">
                                                                        <div class="m-portlet__head">
                                                                            <div class="m-portlet__head-caption">
                                                                                <div class="m-portlet__head-title">
                                                                                    <h3 class="m-portlet__head-text">
                                                                                        Education
                                                                                    </h3>
                                                                                </div>
                                                                            </div>
                                                                            <div class="m-portlet__head-tools">
                                                                                <ul class="m-portlet__nav">
                                                                                    <li class="m-portlet__nav-item">
                                                                                        <a href="" class="btn m-btn--pill m-btn--icon m-btn--icon-only m-btn--air btn-brand m-btn modal-toggle" data-toggle="modal" data-target="#educationModal"><i class="la la-plus"></i></a>
                                                                                    </li>
                                                                                </ul>
                                                                            </div>
                                                                        </div>
                                                                        <div class="m-portlet__body py-0">
                                                                            <div class="tab-content">
                                                                                <div class="tab-pane active">
                                                                                    <div class="m-widget4 m-widget4--progress" id="educationContainer">
                                                                                        <div class="m-widget4__item">
                                                                                            No items.
                                                                                        </div>
                                                                                    </div>
                                                                                </div>
                                                                            </div>
                                                                        </div>
                                                                    </div>
                                                                    <!--end::Portlet-->

                                                                    <!--begin::Portlet-->
                                                                    <div class="m-portlet m-portlet--brand m-portlet--head-solid-bg m-portlet--bordered m-portlet--head-sm">
                                                                        <div class="m-portlet__head">
                                                                            <div class="m-portlet__head-caption">
                                                                                <div class="m-portlet__head-title">
                                                                                    <h3 class="m-portlet__head-text">
                                                                                        Employment
                                                                                    </h3>
                                                                                </div>
                                                                            </div>
                                                                            <div class="m-portlet__head-tools">
                                                                                <ul class="m-portlet__nav">
                                                                                    <li class="m-portlet__nav-item">
                                                                                        <a href="" class="btn m-btn--pill m-btn--icon m-btn--icon-only m-btn--air btn-brand m-btn modal-toggle" data-toggle="modal" data-target="#employmentModal"><i class="la la-plus"></i></a>
                                                                                    </li>
                                                                                </ul>
                                                                            </div>
                                                                        </div>
                                                                        <div class="m-portlet__body py-0">
                                                                            <div class="tab-content">
                                                                                <div class="tab-pane active">
                                                                                    <div class="m-widget4 m-widget4--progress" id="employmentContainer">
                                                                                        <div class="m-widget4__item">
                                                                                            No items.
                                                                                        </div>
                                                                                    </div>
                                                                                </div>
                                                                            </div>
                                                                        </div>
                                                                    </div>
                                                                    <!--end::Portlet-->

                                                                    <!--begin::Portlet-->
                                                                    <div class="m-portlet m-portlet--brand m-portlet--head-solid-bg m-portlet--bordered m-portlet--head-sm">
                                                                        <div class="m-portlet__head">
                                                                            <div class="m-portlet__head-caption">
                                                                                <div class="m-portlet__head-title">
                                                                                    <h3 class="m-portlet__head-text">
                                                                                        Skills
                                                                                    </h3>
                                                                                </div>
                                                                            </div>
                                                                            <div class="m-portlet__head-tools">
                                                                                <ul class="m-portlet__nav">
                                                                                    <li class="m-portlet__nav-item">
                                                                                        <a href="" class="btn m-btn--pill m-btn--icon m-btn--icon-only m-btn--air btn-brand m-btn modal-toggle" data-toggle="modal" data-target="#skillsModal"><i class="la la-plus"></i></a>
                                                                                    </li>
                                                                                </ul>
                                                                            </div>
                                                                        </div>
                                                                        <div class="m-portlet__body py-0">
                                                                            <div class="tab-content">
                                                                                <div class="tab-pane active">
                                                                                    <div class="m-widget4 m-widget4--progress" id="skillsContainer">
                                                                                        <div class="m-widget4__item">
                                                                                            No items.
                                                                                        </div>
                                                                                    </div>
                                                                                </div>
                                                                            </div>
                                                                        </div>
                                                                    </div>
                                                                    <!--end::Portlet-->

                                                                    <!--begin::Portlet-->
                                                                    <div class="m-portlet m-portlet--brand m-portlet--head-solid-bg m-portlet--bordered m-portlet--head-sm">
                                                                        <div class="m-portlet__head">
                                                                            <div class="m-portlet__head-caption">
                                                                                <div class="m-portlet__head-title">
                                                                                    <h3 class="m-portlet__head-text">
                                                                                        Projects
                                                                                    </h3>
                                                                                </div>
                                                                            </div>
                                                                            <div class="m-portlet__head-tools">
                                                                                <ul class="m-portlet__nav">
                                                                                    <li class="m-portlet__nav-item">
                                                                                        <a href="" class="btn m-btn--pill m-btn--icon m-btn--icon-only m-btn--air btn-brand m-btn modal-toggle" data-toggle="modal" data-target="#projectsModal"><i class="la la-plus"></i></a>
                                                                                    </li>
                                                                                </ul>
                                                                            </div>
                                                                        </div>
                                                                        <div class="m-portlet__body py-0">
                                                                            <div class="tab-content">
                                                                                <div class="tab-pane active">
                                                                                    <div class="m-widget4 m-widget4--progress" id="projectsContainer">
                                                                                        <div class="m-widget4__item">
                                                                                            No items.
                                                                                        </div>
                                                                                    </div>
                                                                                </div>
                                                                            </div>
                                                                        </div>
                                                                    </div>
                                                                    <!--end::Portlet-->

                                                                    <!--begin::Portlet-->
                                                                    <div class="m-portlet m-portlet--brand m-portlet--head-solid-bg m-portlet--bordered m-portlet--head-sm">
                                                                        <div class="m-portlet__head">
                                                                            <div class="m-portlet__head-caption">
                                                                                <div class="m-portlet__head-title">
                                                                                    <h3 class="m-portlet__head-text">
                                                                                        Referees
                                                                                    </h3>
                                                                                </div>
                                                                            </div>
                                                                            <div class="m-portlet__head-tools">
                                                                                <ul class="m-portlet__nav">
                                                                                    <li class="m-portlet__nav-item">
                                                                                        <a href="" class="btn m-btn--pill m-btn--icon m-btn--icon-only m-btn--air btn-brand m-btn modal-toggle" data-toggle="modal" data-target="#refereeModal"><i class="la la-plus"></i></a>
                                                                                    </li>
                                                                                </ul>
                                                                            </div>
                                                                        </div>
                                                                        <div class="m-portlet__body py-0">
                                                                            <div class="tab-content">
                                                                                <div class="tab-pane active">
                                                                                    <div class="m-widget4 m-widget4--progress" id="refereesContainer">
                                                                                        <div class="m-widget4__item">
                                                                                            No items.
                                                                                        </div>
                                                                                    </div>
                                                                                </div>
                                                                            </div>
                                                                        </div>
                                                                    </div>
                                                                    <!--end::Portlet-->
                                                                </div>

                                                                <!--begin::Modal-->
                                                                <div class="modal fade" id="educationModal" tabindex="-1" role="dialog" aria-labelledby="exampleModalLabel" aria-hidden="true">
                                                                    <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
                                                                        <div class="modal-content">
                                                                            <div class="modal-header">
                                                                                <h5 class="modal-title" id="educationTitle">Education</h5>
                                                                                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
		          <span aria-hidden="true">&times;</span>
		        </button>
                                                                            </div>
                                                                            <form id="educationForm">
                                                                                <div class="modal-body">
                                                                                    <div class="form-group m-form__group row">
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="edu-level">* Education Level:</label>
                                                                                            <select name="edu-level" class="form-control m-input" required="true">
									<option value="" selected="selected">Select</option>
									<option value="1">Primary School</option>
									<option value="2">Secondary School</option>
									<option value="3">High School</option>
									<option value="4">Certificate</option>
									<option value="5">Diploma</option>
									<option value="6">Profesional Qualifications</option>
									<option value="7">Higher Diploma</option>
									<option value="8">Under Graduate</option>
									<option value="9">Post Graduate</option>
								</select>
                                                                                        </div>
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="institution">* Institution:</label>
                                                                                            <input type="text" name="institution" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="form-group m-form__group row">
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="edu-from">* Date from</label>
                                                                                            <input type="date" name="edu-from" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="edu-to">* Date to</label>
                                                                                            <input type="date" name="edu-to" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="form-group m-form__group row">
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="certification">Certification *</label>
                                                                                            <input type="text" name="certification" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label">Grades</label>
                                                                                            <input type="text" name="grades" class="form-control m-input" placeholder="">
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="form-group m-form__group">
                                                                                        <label>Details</label>
                                                                                        <textarea class="form-control m-input" name="educationDetails" rows="4"></textarea>
                                                                                    </div>

                                                                                    <input type="hidden" name="education_id" value="">
                                                                                </div>
                                                                                <div class="modal-footer">
                                                                                    <button type="reset" data-cancel="educationModal" class="btn btn-outline-brand m-btn cancel-btn" data-dismiss="modal">Cancel</button>
                                                                                    <button type="button" data-save="educationForm" class="btn btn-success save-btn">Add</button>
                                                                                    <button type="button" data-save="educationForm" class="btn btn-brand upd-btn hidden">Update</button>
                                                                                </div>
                                                                            </form>
                                                                        </div>
                                                                    </div>
                                                                </div>
                                                                <!--end::Modal-->

                                                                <!--begin::Modal-->
                                                                <div class="modal fade" id="skillsModal" tabindex="-1" role="dialog" aria-labelledby="exampleModalLabel" aria-hidden="true">
                                                                    <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
                                                                        <div class="modal-content">
                                                                            <div class="modal-header">
                                                                                <h5 class="modal-title" id="exampleModalLabel">Skill</h5>
                                                                                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
		          <span aria-hidden="true">&times;</span>
		        </button>
                                                                            </div>
                                                                            <form id="skillForm">
                                                                                <div class="modal-body">
                                                                                    <div class="form-group m-form__group row">
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="skill-name">* Skill</label>
                                                                                            <select name="skill-name" class="form-control m-input" required="true">
								<option value="" selected="selected">Select</option>
								<option value="1">Personal Computer</option>
								<option value="2">Dot Matrix Printer</option>
								<option value="3">Ticket Printer</option>
								<option value="4">Hp Printer</option>
								<option value="5">Dos</option>
								<option value="6">Windowsxp</option>
								<option value="7">Linux</option>
								<option value="8">Solaris Unix</option>
								<option value="10">Office</option>
							</select>
                                                                                        </div>
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="skill-level">* Skill Level</label>
                                                                                            <select name="skill-level" class="form-control m-input" required="true">
								<option value="" selected="selected">Select</option>
								<option value="1">Advanced</option>
								<option value="2">Basic</option>
								<option value="3">Intermediate</option>
							</select>
                                                                                        </div>
                                                                                    </div>

                                                                                    <div class="form-group m-form__group">
                                                                                        <label>Details</label>
                                                                                        <textarea class="form-control m-input" name="skill-details" id="skillsDetails" rows="4"></textarea>
                                                                                    </div>

                                                                                    <input type="hidden" name="skill_id" value="">
                                                                                </div>
                                                                                <div class="modal-footer">
                                                                                    <button type="reset" data-cancel="skillsModal" class="btn btn-outline-brand m-btn cancel-btn" data-dismiss="modal">Cancel</button>
                                                                                    <button type="button" data-save="skillForm" class="btn btn-success save-btn">Add</button>
                                                                                    <button type="button" data-save="skillForm" class="hidden btn btn-brand upd-btn">Update</button>
                                                                                </div>
                                                                            </form>
                                                                        </div>
                                                                    </div>
                                                                </div>
                                                                <!--end::Modal-->

                                                                <!--begin::Modal-->
                                                                <div class="modal fade" id="employmentModal" tabindex="-1" role="dialog" aria-labelledby="exampleModalLabel" aria-hidden="true">
                                                                    <div class="modal-dialog modal-lg" role="document">
                                                                        <div class="modal-content">
                                                                            <div class="modal-header">
                                                                                <h5 class="modal-title" id="exampleModalLabel">Employment</h5>
                                                                                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
		          <span aria-hidden="true">&times;</span>
		        </button>
                                                                            </div>
                                                                            <form id="employmentForm">
                                                                                <div class="modal-body">
                                                                                    <div class="form-group m-form__group row">
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="employer">* Employer</label>
                                                                                            <input type="text" name="employer" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="position">* Position</label>
                                                                                            <input type="text" name="position" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="form-group m-form__group row">
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="emp-from">* Date from</label>
                                                                                            <input type="date" name="emp-from" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="emp-to">* Date to</label>
                                                                                            <input type="date" name="emp-to" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="form-group m-form__group">
                                                                                        <label>Details</label>
                                                                                        <textarea class="form-control m-input" name="employmentDetails" rows="4"></textarea>
                                                                                    </div>

                                                                                    <input type="hidden" name="employment_id" value="">
                                                                                </div>
                                                                                <div class="modal-footer">
                                                                                    <button type="reset" data-cancel="employmentModal" class="btn btn-outline-brand m-btn cancel-btn" data-dismiss="modal">Cancel</button>
                                                                                    <button type="button" data-save="employmentForm" class="btn btn-success save-btn">Add</button>
                                                                                    <button type="button" data-save="employmentForm" class="hidden btn btn-brand upd-btn">Update</button>
                                                                                </div>
                                                                            </form>
                                                                        </div>
                                                                    </div>
                                                                </div>
                                                                <!--end::Modal-->

                                                                <!--begin::Modal-->
                                                                <div class="modal fade" id="projectsModal" tabindex="-1" role="dialog" aria-labelledby="exampleModalLabel" aria-hidden="true">
                                                                    <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
                                                                        <div class="modal-content">
                                                                            <div class="modal-header">
                                                                                <h5 class="modal-title" id="projectModalLabel">Project</h5>
                                                                                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
		          <span aria-hidden="true">&times;</span>
		        </button>
                                                                            </div>
                                                                            <form id="projectForm">
                                                                                <div class="modal-body">
                                                                                    <div class="form-group m-form__group row">
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="project-name">* Project Name</label>
                                                                                            <input type="text" name="project-name" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="project-date">* Date</label>
                                                                                            <input type="date" name="project-date" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="form-group m-form__group">
                                                                                        <label>Details</label>
                                                                                        <textarea class="form-control m-input" name="projectDetails" rows="4"></textarea>
                                                                                    </div>

                                                                                    <input type="hidden" name="project_id" value="">
                                                                                </div>
                                                                                <div class="modal-footer">
                                                                                    <button type="reset" data-cancel="projectsModal" class="btn btn-outline-brand m-btn cancel-btn" data-dismiss="modal">Cancel</button>
                                                                                    <button type="button" data-save="projectForm" class="btn btn-success save-btn">Add</button>
                                                                                    <button type="button" data-save="projectForm" class="hidden btn btn-brand upd-btn">Update</button>
                                                                                </div>
                                                                            </form>
                                                                        </div>
                                                                    </div>
                                                                </div>
                                                                <!--end::Modal-->

                                                                <!--begin::Modal-->
                                                                <div class="modal fade" id="addressModal" tabindex="-1" role="dialog" aria-labelledby="exampleModalLabel" aria-hidden="true">
                                                                    <div class="modal-dialog modal-lg modal-dialog-centered" role="document">
                                                                        <div class="modal-content">
                                                                            <div class="modal-header">
                                                                                <h5 class="modal-title" id="modalLabel">Address</h5>
                                                                                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
		          <span aria-hidden="true">&times;</span>
		        </button>
                                                                            </div>
                                                                            <form id="addressForm">
                                                                                <div class="modal-body">
                                                                                    <div class="form-group m-form__group row">
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="address-country">* Country</label>
                                                                                            <select name="address-country" class="form-control m-input" required="true">
									<option value="" selected="selected">Country</option>
									<option value="KE">Kenya</option>
								</select>
                                                                                        </div>
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="address-code">* Postal Code</label>
                                                                                            <input type="text" name="address-code" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="form-group m-form__group row">
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="address-box">* P.O.Box</label>
                                                                                            <input type="text" name="address-box" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="address-town">* Town</label>
                                                                                            <input type="text" name="address-town" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="form-group m-form__group row">
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label">Street</label>
                                                                                            <input type="text" name="address-street" class="form-control m-input" placeholder="">
                                                                                        </div>
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label">Premises</label>
                                                                                            <input type="text" name="address-premises" class="form-control m-input" placeholder="">
                                                                                        </div>
                                                                                    </div>

                                                                                    <input type="hidden" name="address_id" value="">
                                                                                </div>
                                                                                <div class="modal-footer">
                                                                                    <button type="reset" data-cancel="addressModal" class="btn btn-outline-brand m-btn cancel-btn" data-dismiss="modal">Cancel</button>
                                                                                    <button type="button" data-save="addressForm" class="btn btn-success save-btn">Add</button>
                                                                                    <button type="button" data-save="addressForm" class="btn btn-brand hidden upd-btn">Update</button>
                                                                                </div>
                                                                            </form>

                                                                        </div>
                                                                    </div>
                                                                </div>
                                                                <!--end::Modal-->

                                                                <!--begin::Modal-->
                                                                <div class="modal fade" id="refereeModal" tabindex="-1" role="dialog" aria-labelledby="exampleModalLabel" aria-hidden="true">
                                                                    <div class="modal-dialog modal-lg" role="document">
                                                                        <div class="modal-content">
                                                                            <div class="modal-header">
                                                                                <h5 class="modal-title" id="exampleModalLabel">Referee</h5>
                                                                                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
																					<span aria-hidden="true">&times;</span>
																					</button>
                                                                            </div>
                                                                            <form id="refereeForm">
                                                                                <div class="modal-body">
                                                                                    <div class="form-group m-form__group">
                                                                                        <label data-name="referee-name">* Name</label>
                                                                                        <input type="text" class="form-control m-input" name="referee-name" placeholder="" required="true">
                                                                                    </div>
                                                                                    <div class="form-group m-form__group row">
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="referee-company">* Company</label>
                                                                                            <input type="text" name="referee-company" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="referee-position">* Position</label>
                                                                                            <input type="text" name="referee-position" class="form-control m-input" placeholder="" required="true">
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="form-group m-form__group row">
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label">Phone</label>
                                                                                            <div class="input-group">
                                                                                                <div class="input-group-prepend"><span class="input-group-text"><i class="la la-phone"></i></span></div>
                                                                                                <input type="text" name="referee-phone" class="form-control m-input" placeholder="">
                                                                                            </div>
                                                                                        </div>
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="referee-email">* Email</label>
                                                                                            <div class="input-group">
                                                                                                <div class="input-group-prepend"><span class="input-group-text">@</span></div>
                                                                                                <input type="text" name="referee-email" class="form-control m-input" placeholder="" required="true">
                                                                                            </div>
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="form-group m-form__group row">
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label" data-name="referee-country">* Country</label>
                                                                                            <select name="referee-country" class="form-control m-input" required="true">
																								<option value="" selected="selected">Country</option>
																								<option value="KE">Kenya</option>
																							</select>
                                                                                        </div>
                                                                                        <div class="col-lg-6 m-form__group-sub">
                                                                                            <label class="form-control-label">Town</label>
                                                                                            <input type="text" name="referee-town" class="form-control m-input" placeholder="">
                                                                                        </div>

                                                                                        <input type="hidden" name="referee_id" value="">
                                                                                    </div>
                                                                                </div>
                                                                                <div class="modal-footer">
                                                                                    <button type="reset" data-cancel="refereeModal" class="btn btn-outline-brand m-btn cancel-btn" data-dismiss="modal">Cancel</button>
                                                                                    <button type="button" data-save="refereeForm" class="btn btn-success save-btn">Add</button>
                                                                                    <button type="button" data-save="refereeForm" class="hidden btn btn-brand upd-btn">Update</button>
                                                                                </div>
                                                                            </form>
                                                                        </div>
                                                                    </div>
                                                                </div>
                                                                <!--end::Modal-->

                                                            </div>

                                                            <div class="col-lg-6">

                                                                <div class="m-subheader pt-0">
                                                                    <div class="d-flex align-items-center">
                                                                        <div class="mr-auto">
                                                                            <h3 class="m-subheader__title">Resume Preview</h3>
                                                                        </div>
                                                                    </div>
                                                                </div>

                                                                <div class="m-content py-0">
                                                                    <!--begin::Portlet-->
                                                                    <div class="m-portlet m-portlet--info m-portlet--head-solid-bg m-portlet--bordered m-portlet--bordered-semi mb-0">
                                                                        <div class="m-portlet__body">
                                                                            <div class="m-portlet__head-caption">
                                                                                <div class="m-portlet__head-title">
                                                                                    <h3 class="m-portlet__head-text">
                                                                                        <span data-display="othername" class="mr-1"></span><span data-display="surname"></span>

                                                                                    </h3>
                                                                                </div>
                                                                            </div>
                                                                            <div class="tab-content">
                                                                                <div class="tab-pane active">
                                                                                    <div class="m-widget4">
                                                                                        <div class="m-widget4__item py-0">
                                                                                            <div class="m-widget4__info px-0">
                                                                                                <span class="m-widget4__title">
											Email:
											</span>
                                                                                                <span class="m-widget4__sub">
											<a href="mailto:" data-display="email"></a>
											</span>
                                                                                            </div>
                                                                                        </div>
                                                                                        <div class="m-widget4__item py-0">
                                                                                            <div class="m-widget4__info px-0">
                                                                                                <span class="m-widget4__title">
											Phone:
											</span>
                                                                                                <span class="m-widget4__sub">
											<a href="tel:" data-display="phone"></a>
											</span>
                                                                                            </div>
                                                                                        </div>
                                                                                        <div class="m-widget4__item py-0">
                                                                                            <div class="m-widget4__info px-0">
                                                                                                <span class="m-widget4__title">
											Date of Birth:
											</span>
                                                                                                <span class="m-widget4__sub" data-display="dob">
											</span>
                                                                                            </div>
                                                                                        </div>
                                                                                        <div class="m-widget4__item py-0">
                                                                                            <div class="m-widget4__info px-0">
                                                                                                <span class="m-widget4__title">
											Gender:
											</span>
                                                                                                <span class="m-widget4__sub" data-display="gender">
											</span>
                                                                                            </div>
                                                                                        </div>
                                                                                        <div class="m-widget4__item py-0">
                                                                                            <div class="m-widget4__info px-0">
                                                                                                <span class="m-widget4__title">
											Marital Status:
											</span>
                                                                                                <span class="m-widget4__sub" data-display="marital-status">
											</span>
                                                                                            </div>
                                                                                        </div>
                                                                                        <div class="m-widget4__item py-0">
                                                                                            <div class="m-widget4__info px-0">
                                                                                                <span class="m-widget4__title">
											Nationality:
											</span>
                                                                                                <span class="m-widget4__sub" data-display="nationality">
											</span>
                                                                                            </div>
                                                                                        </div>
                                                                                        <div class="m-widget4__item py-0">
                                                                                            <div class="m-widget4__info px-0">
                                                                                                <span class="m-widget4__title">
											Language:
											</span>
                                                                                                <span class="m-widget4__sub" data-display="language">
											</span>
                                                                                            </div>
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="m-widget4">
                                                                                        <div class="m-widget4__item pb-0">
                                                                                            <div class="m-widget4__info px-0">
                                                                                                <span class="m-widget4__title">Address</span><br>
                                                                                                <div id="resumeAddress"></div>
                                                                                            </div>
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="m-widget4">
                                                                                        <div class="m-widget4__item pb-0">
                                                                                            <div class="m-widget4__info px-0">
                                                                                                <span class="m-widget4__title">Education</span><br>
                                                                                                <div id="resumeEducation"></div>
                                                                                            </div>
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="m-widget4">
                                                                                        <div class="m-widget4__item pb-0">
                                                                                            <div class="m-widget4__info px-0">
                                                                                                <span class="m-widget4__title">Employment</span><br>
                                                                                                <div id="resumeEmployment"></div>
                                                                                            </div>
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="m-widget4">
                                                                                        <div class="m-widget4__item pb-0">
                                                                                            <div class="m-widget4__info px-0">
                                                                                                <span class="m-widget4__title">Projects</span><br>
                                                                                                <div id="resumeProjects"></div>
                                                                                            </div>
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="m-widget4">
                                                                                        <div class="m-widget4__item pb-0">
                                                                                            <div class="m-widget4__info px-0">
                                                                                                <span class="m-widget4__title">Skills</span><br>
                                                                                                <div id="resumeSkills"></div>
                                                                                            </div>
                                                                                        </div>
                                                                                    </div>
                                                                                    <div class="m-widget4">
                                                                                        <div class="m-widget4__item">
                                                                                            <div class="m-widget4__info px-0">
                                                                                                <span class="m-widget4__title">Referees</span><br>
                                                                                                <div id="resumeReferees"></div>
                                                                                            </div>
                                                                                        </div>
                                                                                    </div>
                                                                                </div>
                                                                            </div>

                                                                        </div>
                                                                    </div>
                                                                    <!--end::Portlet-->
                                                                </div>
                                                            </div>

                                                        </div>

                                                    </div>
                                                </div>


                                            </div>
                                            <!-- end:: Body -->
                                        </section>


                                        <!-- begin::Footer -->
                                        <!-- end::Footer -->


                                    </div>
                                    <!-- end:: Page -->

                                    <!--begin::Global Theme Bundle -->
                                    <script src="assets/global/plugins/jquery.min.js" type="text/javascript"></script>
                                    <script src="assets/resume/vendor/vendors.bundle.js" type="text/javascript"></script>
                                    <script src="assets/resume/vendor/scripts.bundle.js" type="text/javascript"></script>

                                    <script src="assets/resume/js/resume.js" type="text/javascript"></script>
                                    <script src="assets/resume/js/resume-api.js" type="text/javascript"></script>
                                    <!--end::Global Theme Bundle -->

                                    <script type="text/javascript">
                                        resumeApi.init();
                                    </script>

                                    <script type="text/javascript">
                                        $('#detailsForm .m-input').on('change', function() {
                                            var textValue = $(this).val();
                                            var target = $(this).attr('name');
                                            $("[data-display=" + target + "]").html(textValue);
                                        });

                                        $(".m-input").on('change', function() {
                                            if ($(this).attr('name').includes('email')) {
                                                const re = /^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
                                                if (!re.test(String($(this).val()).toLowerCase())) {
                                                    $(this).css({
                                                        "border": "1px solid #ff000087"
                                                    });
                                                    $("[data-name='" + $(this).attr('name') + "']").addClass('text-danger');
                                                } else {
                                                    $(this).css({
                                                        "border": "1px solid #ebedf2"
                                                    });
                                                    $("[data-name='" + $(this).attr('name') + "']").removeClass('text-danger');
                                                }
                                            } else if ($(this).val() == "" && $(this).prop('required') == true) {
                                                $(this).css({
                                                    "border": "1px solid #ff000087"
                                                });
                                                $("[data-name='" + $(this).attr('name') + "']").addClass('text-danger');
                                            } else {
                                                $("[data-name='" + $(this).attr('name') + "']").removeClass('text-danger');
                                                $(this).css({
                                                    "border": "1px solid #ebedf2"
                                                });
                                            }
                                        });
                                    </script>

                                    <script type="text/javascript">
                                        $('#saveProfile').on('click', function() {
                                            calculateProgress();
                                        });

                                        $('.modal-toggle').on('click', function() {
                                            let modalID = $(this).attr('data-target');
                                            $(modalID).find(".save-btn").removeClass('hidden');
                                            $(modalID).find(".upd-btn").addClass('hidden');
                                        });
                                    </script>

                                </body>
                                <!-- end::Body -->

                                </html>

                                <% 	web.close(); %>